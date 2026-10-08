"""Scenario packages (spec §7): a directory with scenario.yaml, setup.sh, verify.sh and score.yaml. Everything is data:
no scenario is known to the code. Packages are validated before they are stored; scripts are stored per version in
the database and only ever run inside a lab container."""
import re
from pathlib import Path

import yaml
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import Scenario, ScenarioVersion, SystemSetting

CATEGORIES = ["Linux", "SSH", "Networking", "Nginx", "Apache", "PHP", "PHP-FPM", "MariaDB", "Systemd", "Storage",
              "Permissions", "Security basics", "Storage/Application"]
DIFFICULTIES = ["easy", "intermediate", "advanced"]
SLUG = re.compile(r"^[a-z0-9][a-z0-9-]{1,62}$")
IMAGE = re.compile(r"^linux-training-[a-z0-9-]+(:[A-Za-z0-9_.-]+)?$")  # only the platform's own lab images
CHECK = re.compile(r"^[a-z][a-z0-9_]{0,63}$")
MAX_SCRIPT = 64 * 1024
CAPABILITIES = {"NET_ADMIN", "NET_RAW", "SYS_PTRACE", "SYS_NICE", "SYS_RESOURCE"}  # extra caps a scenario may ask for
FILES = ("scenario.yaml", "setup.sh", "verify.sh", "score.yaml")


class ScenarioError(ValueError):
    pass


def parse_score(text: str) -> dict:
    """score.yaml: either {check: points} or
    {pass_score: 70, items: {check: {points: 20, label: "...", partial: true}}, deductions: {name: {points: 5, ...}},
     process: {name: {points: 5, label: "...", any_of: ["regex", ...]}}}.
    Normalised to the long form."""
    try:
        data = yaml.safe_load(text) or {}
    except yaml.YAMLError as e:
        raise ScenarioError(f"score.yaml: {e}")
    if not isinstance(data, dict):
        raise ScenarioError("score.yaml must be a mapping")
    if "items" not in data:  # short form
        data = {"items": data}
    out = {"pass_score": int(data.get("pass_score", 70)), "items": {}, "deductions": {}, "process": {}}
    for section in ("items", "deductions", "process"):
        sec = data.get(section) or {}
        if not isinstance(sec, dict):
            raise ScenarioError(f"score.yaml: {section} must be a mapping")
        for name, spec in sec.items():
            if not CHECK.match(str(name)):
                raise ScenarioError(f"score.yaml: bad check name {name!r} (lowercase letters, digits, _)")
            if isinstance(spec, (int, float)):
                spec = {"points": spec}
            if not isinstance(spec, dict) or not isinstance(spec.get("points"), (int, float)) or not 0 < spec["points"] <= 1000:
                raise ScenarioError(f"score.yaml: {section}.{name} needs points between 1 and 1000")
            item = {"points": spec["points"], "label": str(spec.get("label", name.replace("_", " ")))[:200]}
            if section == "items":
                item["partial"] = bool(spec.get("partial", False))
            if section == "process":
                pats = spec.get("any_of") or []
                if not pats or not all(isinstance(p, str) for p in pats):
                    raise ScenarioError(f"score.yaml: process.{name} needs any_of: [regex, ...]")
                for p in pats:
                    try:
                        re.compile(p)
                    except re.error as e:
                        raise ScenarioError(f"score.yaml: process.{name}: bad regex {p!r}: {e}")
                item["any_of"] = pats
            out[section][str(name)] = item
    if not out["items"]:
        raise ScenarioError("score.yaml: no scored checks")
    if not 0 < out["pass_score"] <= 100:
        raise ScenarioError("score.yaml: pass_score must be 1-100 (percent)")
    return out


def validate_script(name: str, text: str) -> str:
    if not text.strip():
        raise ScenarioError(f"{name} is empty")
    if len(text.encode()) > MAX_SCRIPT:
        raise ScenarioError(f"{name} is larger than {MAX_SCRIPT // 1024} KB")
    if "\x00" in text:
        raise ScenarioError(f"{name} contains NUL bytes")
    return text.replace("\r\n", "\n")


def validate_meta(meta: dict, max_weight: int | None = None) -> dict:
    def need(k, typ):
        if k not in meta:
            raise ScenarioError(f"scenario.yaml: {k} is required")
        try:
            return typ(meta[k])
        except (TypeError, ValueError):
            raise ScenarioError(f"scenario.yaml: {k} must be {typ.__name__}")
    out = {
        "name": need("name", str).strip()[:200],
        "description": str(meta.get("description", "")).strip(),
        "category": need("category", str),
        "difficulty": need("difficulty", str).lower(),
        "docker_image": need("docker_image", str),
        "time_limit": need("time_limit", int),
        "resource_weight": need("resource_weight", int),
    }
    if not out["name"]:
        raise ScenarioError("scenario.yaml: name is empty")
    if out["category"] not in CATEGORIES:
        raise ScenarioError(f"category must be one of {', '.join(CATEGORIES)}")
    if out["difficulty"] not in DIFFICULTIES:
        raise ScenarioError(f"difficulty must be one of {', '.join(DIFFICULTIES)}")
    if not IMAGE.match(out["docker_image"]):
        raise ScenarioError("docker_image must be one of the platform's lab images (linux-training-...)")
    if not 1 <= out["time_limit"] <= 600:
        raise ScenarioError("time_limit must be 1-600 minutes")
    if not 1 <= out["resource_weight"] <= (max_weight or 200):
        raise ScenarioError(f"resource_weight must be 1-{max_weight or 200}" + (" (the maximum resource weight)" if max_weight else ""))
    extra = {}
    caps = meta.get("capabilities") or []
    if not isinstance(caps, list) or not set(caps) <= CAPABILITIES:
        raise ScenarioError(f"capabilities may only list {', '.join(sorted(CAPABILITIES))}")
    extra["capabilities"] = sorted(caps)
    tmpfs = meta.get("tmpfs") or {}  # small separate filesystems (disk-full scenarios): {path: size_mb}
    if not isinstance(tmpfs, dict) or len(tmpfs) > 4:
        raise ScenarioError("tmpfs must be a mapping of up to 4 paths")
    for p, mb in tmpfs.items():
        if not re.match(r"^/(srv|data|var/www|var/log/app|var/lib/app|opt/app|mnt)(/[A-Za-z0-9._-]+)*$", str(p)) or ".." in str(p):
            raise ScenarioError(f"tmpfs path {p!r} is not allowed")
        if not isinstance(mb, int) or not 1 <= mb <= 256:
            raise ScenarioError(f"tmpfs {p}: size must be 1-256 MB")
    extra["tmpfs"] = {str(k): int(v) for k, v in tmpfs.items()}
    collect = meta.get("collect") or []  # commands whose output is kept as the final state
    if not isinstance(collect, list) or len(collect) > 12 or not all(isinstance(c, str) and len(c) < 300 for c in collect):
        raise ScenarioError("collect must be a list of up to 12 commands")
    extra["collect"] = collect
    out["extra"] = extra
    return out


def read_package(root: Path, slug: str) -> dict:
    """Reads and validates a package directory under root (no path may leave root)."""
    if not SLUG.match(slug):
        raise ScenarioError(f"bad scenario directory name {slug!r}")
    base = (root / slug).resolve()
    if base.parent != root.resolve() or not base.is_dir():
        raise ScenarioError(f"{slug}: not a scenario directory")
    files = {}
    for f in FILES:
        p = (base / f)
        if p.is_symlink() or not p.is_file():
            raise ScenarioError(f"{slug}: {f} is missing")
        if p.stat().st_size > MAX_SCRIPT:
            raise ScenarioError(f"{slug}: {f} is too large")
        files[f] = p.read_text(encoding="utf-8")
    try:
        meta = yaml.safe_load(files["scenario.yaml"]) or {}
    except yaml.YAMLError as e:
        raise ScenarioError(f"{slug}: scenario.yaml: {e}")
    if not isinstance(meta, dict):
        raise ScenarioError(f"{slug}: scenario.yaml must be a mapping")
    pkg = validate_meta(meta)
    pkg["slug"] = slug
    pkg["setup_script"] = validate_script("setup.sh", files["setup.sh"])
    pkg["verify_script"] = validate_script("verify.sh", files["verify.sh"])
    pkg["score_config"] = parse_score(files["score.yaml"])
    pkg["pass_score"] = pkg["score_config"]["pass_score"]
    return pkg


def add_version(db: Session, sc: Scenario, setup: str, verify: str, score: dict, extra: dict, by: str) -> ScenarioVersion:
    n = (max((v.version for v in sc.versions), default=0)) + 1
    v = ScenarioVersion(scenario=sc, version=n, setup_script=setup, verify_script=verify, score_config=score, extra=extra, created_by=by)
    db.add(v)
    db.flush()
    sc.current_version_id = v.id
    return v


def create(db: Session, pkg: dict, by: str) -> Scenario:
    if db.scalar(select(Scenario).where(Scenario.slug == pkg["slug"])):
        raise ScenarioError(f"a scenario {pkg['slug']!r} already exists")
    sc = Scenario(slug=pkg["slug"], **{k: pkg[k] for k in ("name", "description", "category", "difficulty", "docker_image",
                                                           "time_limit", "resource_weight", "pass_score")})
    db.add(sc)
    db.flush()
    add_version(db, sc, pkg["setup_script"], pkg["verify_script"], pkg["score_config"], pkg["extra"], by)
    return sc


SEEDED_KEY = "seeded_scenarios"


def seed(db: Session, root: Path) -> dict:
    """Imports every package under root once. A slug imported before is never imported again, so scenarios the
    administrator edited or deleted stay as they are (the list lives in system_settings)."""
    row = db.get(SystemSetting, SEEDED_KEY)
    done = set(filter(None, (row.value if row else "").split(",")))
    added, skipped, errors = [], [], {}
    if not root.is_dir():
        return {"added": added, "skipped": skipped, "errors": {"": f"{root} is not a directory"}}
    for d in sorted(p.name for p in root.iterdir() if p.is_dir() and not p.name.startswith(".")):
        if d in done:
            skipped.append(d)
            continue
        try:
            pkg = read_package(root, d)
            if db.scalar(select(Scenario).where(Scenario.slug == d)) is None:
                create(db, pkg, "seed")
                added.append(d)
            done.add(d)
        except ScenarioError as e:
            errors[d] = str(e)
    if row:
        row.value = ",".join(sorted(done))
    else:
        db.add(SystemSetting(key=SEEDED_KEY, value=",".join(sorted(done))))
    db.commit()
    return {"added": added, "skipped": skipped, "errors": errors}
