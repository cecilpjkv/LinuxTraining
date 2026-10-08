"""Proves every scenario package in a real lab (run on the Docker host, in the dev image, with the lab daemon's socket):

  1. setup.sh succeeds and the problem is in place (at least one scored check fails),
  2. solution.sh (a reference fix kept next to the package, never imported or shown to technicians) succeeds,
  3. verify.sh then reports every scored check PASS and no deduction.

    python scripts/check_scenarios.py [name-or-prefix ...]      (default: every package with a solution.sh)
"""
import sys
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, "/app")
from app.services import scenario_manager as sm  # noqa: E402
from app.services.lab_manager import LabManager, LabSpec  # noqa: E402
from app.services.scoring import parse, run_verify, score  # noqa: E402
import app.services.lab_manager as _lm  # noqa: E402

ROOT = Path("/srv/scenarios")
labs = LabManager(owner="checker")
_lm.labs = labs  # run_verify uses the module's manager


def check(slug: str) -> tuple[str, bool, str]:
    t0 = time.time()
    try:
        pkg = sm.read_package(ROOT, slug)
    except sm.ScenarioError as e:
        return slug, False, f"package: {e}"
    sol = ROOT / slug / "solution.sh"
    if not sol.is_file():
        return slug, False, "no solution.sh"
    aid = 600000 + uuid.uuid4().int % 99999
    try:
        labs.create(LabSpec(attempt_id=aid, image=pkg["docker_image"], cpu=1.0, memory_mb=512, pids_limit=512,
                            capabilities=pkg["extra"]["capabilities"], tmpfs=pkg["extra"]["tmpfs"]))
        labs.wait_ready(aid)
        r = labs.run_script(aid, pkg["setup_script"], timeout=300)
        if r.exit_code != 0:
            return slug, False, f"setup.sh exit {r.exit_code}: {r.output[-600:]}"
        before = parse(run_verify(aid, pkg["verify_script"]).output)["checks"]
        failing = [n for n in pkg["score_config"]["items"] if before.get(n, {}).get("status") != "PASS"]
        if not failing:
            return slug, False, "the problem is not in place after setup.sh (every check passes)"
        r = labs.run_script(aid, sol.read_text(), timeout=300)
        if r.exit_code != 0:
            return slug, False, f"solution.sh exit {r.exit_code}: {r.output[-600:]}"
        vr = run_verify(aid, pkg["verify_script"])
        out = vr.output
        if "@@LT " not in out:
            return slug, False, f"verify.sh reported nothing after the fix (exit {vr.exit_code}): {out[-300:]!r}"
        res = score(pkg["score_config"], out, [])
        bad = [f"{b['item']}={b['status']}({b['reason'][:120]})" for b in res["breakdown"] if b["kind"] == "state" and b["status"] != "PASS"]
        ded = [b["item"] for b in res["breakdown"] if b["kind"] == "deduction"]
        if bad or ded:
            return slug, False, f"after the fix: {'; '.join(bad)} {'deductions: ' + ','.join(ded) if ded else ''}"
        return slug, True, f"broken: {','.join(failing)} -> fixed in {time.time() - t0:.0f}s"
    except Exception as e:  # noqa: BLE001
        return slug, False, f"{type(e).__name__}: {e}"
    finally:
        labs.destroy(aid)


def main() -> int:
    want = sys.argv[1:]
    slugs = sorted(p.name for p in ROOT.iterdir() if p.is_dir() and (p / "solution.sh").exists())
    if want:
        slugs = [s for s in slugs if any(s == w or s.startswith(w) for w in want)]
    ok = 0
    with ThreadPoolExecutor(max_workers=2) as ex:  # the test host has 1 CPU / 2 GB
        for slug, good, msg in ex.map(check, slugs):
            ok += good
            print(f"{'PASS' if good else 'FAIL'}  {slug:42} {msg}", flush=True)
    print(f"\n{ok}/{len(slugs)} scenarios proven")
    return 0 if ok == len(slugs) else 1


if __name__ == "__main__":
    sys.exit(main())
