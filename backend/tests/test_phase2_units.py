import io
import tarfile
import zipfile
from pathlib import Path

import pytest

from app.services import scenario_manager as sm
from app.services.scheduler import pick
from app.services.scoring import parse, score

SCEN = Path("/srv/scenarios")


class A:
    def __init__(self, i, w):
        self.id, self.resource_weight = i, w


def ids(xs):
    return [x.id for x in xs]


def test_pick_limits():
    q = [A(1, 2), A(2, 2), A(3, 2)]
    assert ids(pick(q, 0, 0, 2, 4)) == [1, 2]           # spec example: two weight-2 labs fill 4, the third waits
    assert ids(pick(q, 1, 2, 2, 4)) == [1]
    assert ids(pick([A(1, 4), A(2, 1)], 0, 0, 2, 4)) == [1]  # a weight-4 lab runs alone
    assert ids(pick([A(2, 1)], 1, 4, 2, 4)) == []        # nothing starts next to it
    assert ids(pick([A(1, 4), A(2, 2)], 1, 2, 2, 4)) == [2]  # a heavy head does not block a lighter one that fits
    assert ids(pick(q, 2, 2, 2, 10)) == []               # the count limit holds whatever the weight


def test_scoring_state_process_deductions():
    cfg = sm.parse_score("""
pass_score: 70
items:
  a: {points: 50}
  b: {points: 30, partial: true}
  c: 20
process:
  logs: {points: 10, any_of: ['journalctl']}
deductions:
  removed: {points: 15}
""")
    out = "x\n@@LT PASS a ok\n@@LT PARTIAL b 0.5 half\n@@LT FAIL c broken\n@@LT DEDUCT removed gone\n"
    r = score(cfg, out, ["ls", "journalctl -u nginx"])
    assert r["maximum"] == 110 and r["total"] == 50 + 15 + 10 - 15
    assert r["passed"] is False  # 60/110
    kinds = {b["item"]: (b["points"], b["kind"]) for b in r["breakdown"]}
    assert kinds["b"] == (15, "state") and kinds["logs"] == (10, "process") and kinds["removed"] == (-15, "deduction")


def test_scoring_missing_and_partial_not_allowed():
    cfg = sm.parse_score("a: 50\nb: 50\n")
    r = score(cfg, "@@LT PARTIAL a 0.9 nearly\n", [])
    assert r["total"] == 0 and {b["status"] for b in r["breakdown"]} == {"PARTIAL", "MISSING"}
    assert parse("@@LT FAIL a x\n@@LT PASS a y\n")["checks"]["a"]["status"] == "FAIL"  # the worse result stays


def test_bad_score_files():
    for bad in ["[]", "a: -5", "A-b: 5", "items: {}", "process: {p: {points: 5, any_of: ['(']}}\nitems: {a: 1}"]:
        with pytest.raises(sm.ScenarioError):
            sm.parse_score(bad)


def test_repo_packages_valid():
    for d in sorted(p.name for p in SCEN.iterdir() if p.is_dir()):
        pkg = sm.read_package(SCEN, d)
        assert pkg["docker_image"].startswith("linux-training-")


def test_meta_validation():
    good = {"name": "x", "category": "Linux", "difficulty": "easy", "docker_image": "linux-training-base", "time_limit": 10,
            "resource_weight": 1}
    assert sm.validate_meta(good)["extra"] == {"capabilities": [], "tmpfs": {}, "collect": []}
    for change in [{"docker_image": "ubuntu"}, {"docker_image": "linux-training-x;rm"}, {"category": "Windows"},
                   {"resource_weight": 9}, {"capabilities": ["SYS_ADMIN"]}, {"tmpfs": {"/etc": 10}},
                   {"tmpfs": {"/data/../etc": 10}}, {"time_limit": 0}]:
        with pytest.raises(sm.ScenarioError):
            sm.validate_meta({**good, **change}, max_weight=4)


def _zip(files):
    b = io.BytesIO()
    with zipfile.ZipFile(b, "w") as z:
        for n, d in files.items():
            z.writestr(n, d)
    return b.getvalue()


def _pkg_files(prefix=""):
    src = SCEN / "nginx-config-syntax"
    return {prefix + f: (src / f).read_text() for f in sm.FILES}


def test_upload_zip_and_traversal(admin):
    r = admin.post("/api/admin/scenarios/upload", files={"file": ("pkg.zip", _zip(_pkg_files("uploaded-one/")))})
    assert r.status_code == 201, r.text
    assert r.json()["slug"] == "uploaded-one" and r.json()["version"] == 1
    evil = _pkg_files("x/")
    evil["../setup.sh"] = "echo pwned"
    r = admin.post("/api/admin/scenarios/upload", files={"file": ("evil.zip", _zip(evil))})
    assert r.status_code == 422 and "unsafe path" in r.json()["detail"]


def test_upload_tar_symlink_refused(admin):
    b = io.BytesIO()
    with tarfile.open(fileobj=b, mode="w:gz") as t:
        ti = tarfile.TarInfo("p/setup.sh")
        ti.type, ti.linkname = tarfile.SYMTYPE, "/etc/shadow"
        t.addfile(ti)
    r = admin.post("/api/admin/scenarios/upload", files={"file": ("p.tar.gz", b.getvalue())})
    assert r.status_code == 422 and "regular files" in r.json()["detail"]
