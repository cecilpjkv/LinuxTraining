"""Real Docker: a lab from the platform image, the nginx scenario's setup, the break confirmed, a technician's fix,
verification passing, destruction. Skipped where Docker or the lab images are unavailable."""
import uuid

import pytest

from app.services import scenario_manager as sm
from app.services.lab_manager import LabManager, LabSpec
from app.services.scoring import confirm_broken, run_verify, score

docker = pytest.importorskip("docker")


@pytest.fixture(scope="module")
def mgr():
    m = LabManager()
    try:
        m.client.images.get("linux-training-web")
    except Exception:
        pytest.skip("Docker or the lab image linux-training-web is not available")
    return m


class V:  # a scenario version without the database
    def __init__(self, pkg):
        self.verify_script, self.score_config = pkg["verify_script"], pkg["score_config"]


def test_nginx_scenario_end_to_end(mgr, monkeypatch):
    import app.services.lab_manager as lm
    monkeypatch.setattr(lm, "labs", mgr)
    pkg = sm.read_package(__import__("pathlib").Path("/srv/scenarios"), "nginx-config-syntax")
    aid = 900000 + uuid.uuid4().int % 99999
    try:
        mgr.create(LabSpec(attempt_id=aid, image=pkg["docker_image"], cpu=0.5, memory_mb=512, pids_limit=512,
                           capabilities=[], tmpfs={}))
        assert mgr.wait_ready(aid) in ("running", "degraded")
        c = mgr.client.containers.get(mgr.name(aid))
        hc = c.attrs["HostConfig"]
        assert not hc["Privileged"] and hc["CapAdd"] == ["SYS_ADMIN"] and hc["PidsLimit"] == 512
        assert hc["Memory"] == 512 * 2**20 and hc["NanoCpus"] == 5 * 10**8 and not hc["Binds"]
        assert c.attrs["Config"]["Hostname"] == "training"
        r = mgr.run_script(aid, pkg["setup_script"])
        assert r.exit_code == 0, r.output
        ok, why = confirm_broken(aid, V(pkg))
        assert ok, why
        # no copy of the scripts inside the lab
        assert mgr.exec(aid, ["sh", "-c", "grep -rl 'colleague' / --include=*.sh 2>/dev/null | head -1"]).output.strip() == ""
        before = score(pkg["score_config"], run_verify(aid, pkg["verify_script"]).output, [])
        assert not before["passed"]
        # the technician's shell has no CAP_SYS_ADMIN
        bnd = mgr.exec(aid, ["/usr/local/sbin/lab-shell", "-c", "grep CapBnd /proc/self/status"]).output
        assert int(bnd.split()[-1], 16) & (1 << 21) == 0, bnd
        # no internet from a lab
        assert mgr.exec(aid, ["curl", "-s", "-m", "5", "-o", "/dev/null", "http://1.1.1.1/"]).exit_code != 0
        # the fix a technician would make
        fix = "sed -i 's|add_header X-Shop-Version \"2.4\"$|add_header X-Shop-Version \"2.4\";|' /etc/nginx/conf.d/shop.conf && nginx -t && systemctl restart nginx"
        assert mgr.exec(aid, ["bash", "-c", fix]).exit_code == 0
        after = score(pkg["score_config"], run_verify(aid, pkg["verify_script"]).output, ["nginx -t", "systemctl status nginx"])
        assert after["passed"] and after["total"] == after["maximum"], after["breakdown"]
    finally:
        mgr.destroy(aid)
    assert not mgr.running(aid)
