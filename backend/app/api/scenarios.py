import io
import tarfile
import tempfile
import zipfile
from pathlib import Path

import yaml
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..deps import current_user, require_admin
from ..models import Scenario, ScenarioVersion, User
from ..schemas import ScenarioAdminOut, ScenarioIn, ScenarioOut, ScenarioPatch
from ..services import scenario_manager as sm
from ..services import settings_store

router = APIRouter(tags=["scenarios"])


@router.get("/api/scenarios", response_model=list[ScenarioOut])
def list_enabled(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return db.scalars(select(Scenario).where(Scenario.enabled.is_(True)).order_by(Scenario.category, Scenario.name)).all()


@router.get("/api/scenarios/meta")
def meta(user: User = Depends(current_user)):
    return {"categories": sm.CATEGORIES, "difficulties": sm.DIFFICULTIES, "capabilities": sorted(sm.CAPABILITIES)}


# --- admin ---

admin = APIRouter(prefix="/api/admin/scenarios", tags=["admin"], dependencies=[Depends(require_admin)])


def _out(sc: Scenario) -> ScenarioAdminOut:
    o = ScenarioAdminOut.model_validate(sc)
    v = sc.current_version
    if v:
        o.version, o.setup_script, o.verify_script = v.version, v.setup_script, v.verify_script
        o.score_yaml = yaml.safe_dump(v.score_config, sort_keys=False)
        o.options = v.extra
    return o


@admin.get("", response_model=list[ScenarioAdminOut])
def admin_list(db: Session = Depends(get_db)):
    return [_out(s) for s in db.scalars(select(Scenario).order_by(Scenario.category, Scenario.name))]


@admin.get("/{sid}", response_model=ScenarioAdminOut)
def admin_get(sid: int, db: Session = Depends(get_db)):
    sc = db.get(Scenario, sid)
    if not sc:
        raise HTTPException(404, "no such scenario")
    return _out(sc)


@admin.get("/{sid}/versions")
def versions(sid: int, db: Session = Depends(get_db)):
    return [{"id": v.id, "version": v.version, "created_at": v.created_at, "created_by": v.created_by}
            for v in db.scalars(select(ScenarioVersion).where(ScenarioVersion.scenario_id == sid).order_by(ScenarioVersion.version.desc()))]


def _validated(db: Session, data: dict) -> dict:
    cfg = settings_store.get_all(db)
    meta = {k: data[k] for k in ("name", "description", "category", "difficulty", "docker_image", "time_limit", "resource_weight")}
    meta.update(data.get("options") or {})
    pkg = sm.validate_meta(meta, cfg["max_resource_weight"])
    pkg["setup_script"] = sm.validate_script("setup.sh", data["setup_script"])
    pkg["verify_script"] = sm.validate_script("verify.sh", data["verify_script"])
    pkg["score_config"] = sm.parse_score(data["score_yaml"])
    pkg["pass_score"] = pkg["score_config"]["pass_score"]
    return pkg


@admin.post("", response_model=ScenarioAdminOut, status_code=201)
def create(body: ScenarioIn, db: Session = Depends(get_db), user: User = Depends(require_admin)):
    try:
        pkg = _validated(db, body.model_dump())
        pkg["slug"] = body.slug
        sc = sm.create(db, pkg, user.username)
        sc.enabled = body.enabled
        db.commit()
    except sm.ScenarioError as e:
        db.rollback()
        raise HTTPException(422, str(e))
    return _out(sc)


@admin.patch("/{sid}", response_model=ScenarioAdminOut)
def update(sid: int, body: ScenarioPatch, db: Session = Depends(get_db), user: User = Depends(require_admin)):
    sc = db.get(Scenario, sid)
    if not sc:
        raise HTTPException(404, "no such scenario")
    cur = _out(sc)
    merged = {**cur.model_dump(), **body.model_dump(exclude_none=True)}
    try:
        pkg = _validated(db, merged)
    except sm.ScenarioError as e:
        raise HTTPException(422, str(e))
    for k in ("name", "description", "category", "difficulty", "docker_image", "time_limit", "resource_weight", "pass_score"):
        setattr(sc, k, pkg[k])
    if body.enabled is not None:
        sc.enabled = body.enabled
    v = sc.current_version
    # scripts, scoring or lab options changed: a new version (attempts keep the version they ran)
    if not v or (pkg["setup_script"], pkg["verify_script"], pkg["score_config"], pkg["extra"]) != (v.setup_script, v.verify_script, v.score_config, v.extra):
        sm.add_version(db, sc, pkg["setup_script"], pkg["verify_script"], pkg["score_config"], pkg["extra"], user.username)
    db.commit()
    db.refresh(sc)
    return _out(sc)


@admin.delete("/{sid}", status_code=204)
def delete(sid: int, db: Session = Depends(get_db)):
    sc = db.get(Scenario, sid)
    if not sc:
        raise HTTPException(404, "no such scenario")
    from ..models import TrainingAttempt
    from ..services.scheduler import ACTIVE
    if db.scalar(select(TrainingAttempt.id).where(TrainingAttempt.scenario_id == sid, TrainingAttempt.status.in_((*ACTIVE, "queued")))):
        raise HTTPException(409, "the scenario has running or queued attempts; disable it first")
    # attempts keep their name and their own copy of the version reference; the scenario row goes
    for a in db.scalars(select(TrainingAttempt).where(TrainingAttempt.scenario_id == sid)):
        a.scenario_id = None
    sc.current_version_id = None
    db.flush()
    db.delete(sc)
    db.commit()


MAX_UPLOAD = 512 * 1024


@admin.post("/upload", response_model=ScenarioAdminOut, status_code=201)
async def upload(file: UploadFile = File(...), db: Session = Depends(get_db), user: User = Depends(require_admin)):
    """A package as .zip or .tar.gz: one directory (its name is the slug) or the four files at the top level (the slug
    then comes from the file name). Only the four known files are read; links, devices and paths leaving the
    directory are refused."""
    data = await file.read(MAX_UPLOAD + 1)
    if len(data) > MAX_UPLOAD:
        raise HTTPException(413, "package larger than 512 KB")
    name = Path(file.filename or "package").name
    try:
        members = _unpack(name, data)
        slugs = {m.split("/")[0] for m in members if "/" in m}
        if len(slugs) == 1 and all("/" in m for m in members):
            slug, members = slugs.pop(), {m.split("/", 1)[1]: v for m, v in members.items()}
        else:
            slug = name.split(".")[0].lower()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            if not sm.SLUG.match(slug):
                raise sm.ScenarioError(f"bad scenario name {slug!r}")
            (root / slug).mkdir()
            for f in sm.FILES:
                if f not in members:
                    raise sm.ScenarioError(f"{f} is missing in the package")
                (root / slug / f).write_bytes(members[f])
            pkg = sm.read_package(root, slug)
        if pkg["resource_weight"] > settings_store.get_all(db)["max_resource_weight"]:
            raise sm.ScenarioError("resource_weight is above the maximum resource weight")
        sc = sm.create(db, pkg, user.username)
        db.commit()
    except sm.ScenarioError as e:
        db.rollback()
        raise HTTPException(422, str(e))
    return _out(sc)


def _unpack(name: str, data: bytes) -> dict[str, bytes]:
    out: dict[str, bytes] = {}
    def take(path: str, read):
        # checked before any normalisation (found by the tests: stripping "./" characters turned "../../x" into "x")
        parts = path.split("/")
        if path.startswith("/") or "\\" in path or ".." in parts:
            raise sm.ScenarioError(f"unsafe path in package: {path!r}")
        while parts and parts[0] in (".", ""):
            parts = parts[1:]
        if not parts or not parts[-1]:
            return
        if len(parts) > 2:
            raise sm.ScenarioError(f"unsafe path in package: {path!r}")
        p = "/".join(parts)
        if parts[-1] in sm.FILES:
            out[p] = read()
    if name.endswith(".zip"):
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            for i in z.infolist()[:50]:
                if i.file_size > sm.MAX_SCRIPT:
                    raise sm.ScenarioError(f"{i.filename} is too large")
                if (i.external_attr >> 16) & 0o170000 == 0o120000:
                    raise sm.ScenarioError(f"{i.filename}: links are not allowed")
                take(i.filename, lambda i=i: z.read(i))
    elif name.endswith((".tar.gz", ".tgz", ".tar")):
        with tarfile.open(fileobj=io.BytesIO(data)) as t:
            for m in t.getmembers()[:50]:
                if m.isdir():
                    continue
                if not m.isfile():
                    raise sm.ScenarioError(f"{m.name}: only regular files are allowed")
                if m.size > sm.MAX_SCRIPT:
                    raise sm.ScenarioError(f"{m.name} is too large")
                take(m.name, lambda m=m: t.extractfile(m).read())
    else:
        raise sm.ScenarioError("upload a .zip or .tar.gz package")
    return out


@admin.post("/seed")
def seed(db: Session = Depends(get_db)):
    return sm.seed(db, Path(settings.scenarios_dir))
