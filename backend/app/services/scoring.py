"""Scoring Engine (spec §11-12). verify.sh reports each check with helper functions this module prepends (never
stored in the lab, so the technician cannot change them):

    check NAME CMD...           PASS if CMD succeeds, FAIL with its output otherwise
    pass NAME [detail]  /  fail NAME [detail]
    partial NAME FRACTION [detail]   0..1 of the item's points (only if the item allows partial)
    deduct NAME [detail]        apply a deduction from score.yaml

The score is built from the final server state (items), minus deductions, plus process points: regular expressions
matched against the command history (a signal, never the whole score).
"""
import re

PRELUDE = r'''
set +e
export PATH=/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin LC_ALL=C
__lt() { printf '@@LT %s %s %s\n' "$1" "$2" "$(printf '%s' "${3:-}" | tr '\n\r' '  ' | cut -c1-400)"; }
pass() { __lt PASS "$1" "${2:-}"; }
fail() { __lt FAIL "$1" "${2:-}"; }
partial() { __lt PARTIAL "$1" "${2:-0} ${3:-}"; }
deduct() { __lt DEDUCT "$1" "${2:-}"; }
check() { __n=$1; shift; __o=$("$@" 2>&1); if [ $? -eq 0 ]; then pass "$__n" "$(printf '%s' "$__o" | tail -c 200)"; else fail "$__n" "$(printf '%s' "$__o" | tail -c 300)"; fi; }
http_code() { curl -s -o /dev/null -m 10 -w '%{http_code}' "$@"; }
'''

LINE = re.compile(r"^@@LT (PASS|FAIL|PARTIAL|DEDUCT) ([a-z][a-z0-9_]{0,63}) ?(.*)$")


def parse(output: str) -> dict:
    """{name: {"status": PASS|FAIL|PARTIAL, "fraction": f, "detail": s}} and {deduction: detail}."""
    checks, deductions = {}, {}
    for line in output.splitlines():
        m = LINE.match(line.strip())
        if not m:
            continue
        kind, name, rest = m.groups()
        if kind == "DEDUCT":
            deductions[name] = rest
        elif kind == "PARTIAL":
            frac, _, detail = rest.partition(" ")
            try:
                f = max(0.0, min(1.0, float(frac)))
            except ValueError:
                f = 0.0
            checks[name] = {"status": "PARTIAL", "fraction": f, "detail": detail}
        else:
            # a check reported twice keeps the worse result
            if checks.get(name, {}).get("status") == "FAIL":
                continue
            checks[name] = {"status": kind, "fraction": 1.0 if kind == "PASS" else 0.0, "detail": rest}
    return {"checks": checks, "deductions": deductions}


def score(config: dict, verify_output: str, commands: list[str]) -> dict:
    res = parse(verify_output)
    breakdown, total, maximum = [], 0.0, 0.0
    for name, item in config["items"].items():
        c = res["checks"].get(name)
        pts = 0.0
        reason = "not reported by verify.sh" if c is None else c["detail"]
        if c:
            if c["status"] == "PASS":
                pts = item["points"]
            elif c["status"] == "PARTIAL" and item.get("partial"):
                pts = round(item["points"] * c["fraction"], 2)
        breakdown.append({"item": name, "label": item["label"], "points": pts, "max": item["points"], "kind": "state",
                          "status": c["status"] if c else "MISSING", "reason": reason})
        total += pts
        maximum += item["points"]
    for name, item in config.get("process", {}).items():
        pats = [re.compile(p) for p in item["any_of"]]
        hit = next((cmd for cmd in commands for p in pats if p.search(cmd)), None)
        pts = item["points"] if hit else 0.0
        breakdown.append({"item": name, "label": item["label"], "points": pts, "max": item["points"], "kind": "process",
                          "status": "PASS" if hit else "FAIL", "reason": f"ran: {hit}" if hit else "no matching command"})
        total += pts
        maximum += item["points"]
    for name, item in config.get("deductions", {}).items():
        if name in res["deductions"]:
            breakdown.append({"item": name, "label": item["label"], "points": -item["points"], "max": 0, "kind": "deduction",
                              "status": "DEDUCTED", "reason": res["deductions"][name]})
            total -= item["points"]
    total = max(0.0, round(total, 2))
    percent = round(100 * total / maximum, 1) if maximum else 0.0
    return {"total": total, "maximum": maximum, "percent": percent, "passed": percent >= config.get("pass_score", 70),
            "breakdown": breakdown, "checks": res["checks"]}


def run_verify(attempt_id: int, verify_script: str, timeout: int = 180):
    """Runs verify.sh; if it reported nothing at all (seen once in ~50 runs on a loaded host: an empty exec stream),
    it runs once more, so a lost stream never scores a technician 0."""
    import logging
    import time

    from .lab_manager import labs
    r = labs.run_script(attempt_id, PRELUDE + "\n" + verify_script, timeout=timeout)
    if "@@LT " not in r.output:
        logging.getLogger("grading").warning("attempt %s: verify.sh reported nothing (exit %s, %d bytes); running it again",
                                             attempt_id, r.exit_code, len(r.output))
        time.sleep(2)
        r = labs.run_script(attempt_id, PRELUDE + "\n" + verify_script, timeout=timeout)
    return r


def confirm_broken(attempt_id: int, version) -> tuple[bool, str]:
    """After setup.sh: at least one scored check must fail, otherwise the scenario's problem is not in place."""
    r = run_verify(attempt_id, version.verify_script)
    checks = parse(r.output)["checks"]
    items = version.score_config["items"]
    failing = [n for n in items if checks.get(n, {}).get("status") != "PASS"]
    if failing:
        return True, ""
    return False, "verify.sh passes every check right after setup.sh"
