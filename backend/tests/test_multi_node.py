"""Multi-server labs: scenario validation, node addressing, values handed between setups, and a real two-server lab
(skipped without Docker or the lab images)."""
import uuid

import pytest

from app.services import scenario_manager as sm
from app.services.lab_manager import SHARE, ExecResult, LabManager, LabSpec, node_key, node_list

META = {"name": "x", "category": "Linux", "difficulty": "easy", "docker_image": "linux-training-base", "time_limit": 10,
        "resource_weight": 2}


def test_nodes_validated():
    out = sm.validate_meta({**META, "nodes": [{"name": "lb"}, {"name": "app1", "image": "linux-training-web"}]})
    assert out["extra"]["nodes"] == [{"name": "lb", "image": "linux-training-base"}, {"name": "app1", "image": "linux-training-web"}]
    assert "nodes" not in sm.validate_meta(META)["extra"]
    bad = [
        [{"name": "lb"}],                                             # one server: no nodes needed
        [{"name": "lb"}, {"name": "lb"}],                             # names unique
        [{"name": "Web"}, {"name": "db"}],                            # lowercase names
        [{"name": "lb"}, {"name": "db", "image": "alpine"}],          # only the platform's images
        [{"name": "lb", "image": "linux-training-web"}, {"name": "db"}],  # the first is docker_image
        [{"name": "a"}, {"name": "b"}, {"name": "c"}, {"name": "d"}],  # at most three
        [{"name": "a", "ports": [1]}, {"name": "b"}],                  # unknown keys
    ]
    for nodes in bad:
        with pytest.raises(sm.ScenarioError):
            sm.validate_meta({**META, "resource_weight": 4, "nodes": nodes})
    with pytest.raises(sm.ScenarioError):  # every server counts
        sm.validate_meta({**META, "resource_weight": 1, "nodes": [{"name": "a"}, {"name": "b"}]})


def test_nested_containers_option():
    assert sm.validate_meta({**META, "nested_containers": True})["extra"]["nested_containers"] is True
    assert "nested_containers" not in sm.validate_meta(META)["extra"]
    with pytest.raises(sm.ScenarioError):
        sm.validate_meta({**META, "nested_containers": "yes"})


def test_node_addressing():
    assert node_list(None) == [("training", None)] and node_list({}) == [("training", None)]
    extra = {"nodes": [{"name": "lb", "image": "i"}, {"name": "app1", "image": "i"}]}
    assert node_list(extra) == [("lb", None), ("app1", "app1")]
    assert node_key(extra, "") is None and node_key(extra, "lb") is None and node_key(extra, "app1") == "app1"
    assert node_key({}, "") is None and node_key({}, "training") is None
    with pytest.raises(KeyError):
        node_key(extra, "db")
    with pytest.raises(KeyError):
        node_key({}, "app1")
    assert LabManager.name(7) == "training-attempt-7" and LabManager.name(7, "app1") == "training-attempt-7-app1"


class FakeLabs(LabManager):
    """Records the scripts it is asked to run; the first server it runs on shares a value."""

    def __init__(self):
        super().__init__(client=object())
        self.runs = []

    def run_script(self, attempt_id, script, timeout=120, node=None):
        self.runs.append((node, script))
        out = "@@LT SHARE KEY c2VjcmV0+/=\n" if len(self.runs) == 1 else "ok\n"
        return ExecResult(exit_code=0, output=out)


def test_run_on_nodes_order_env_and_shares():
    extra = {"nodes": [{"name": "control", "image": "i"}, {"name": "web1", "image": "i"}]}
    m = FakeLabs()
    res = m.run_on_nodes(1, extra, "echo hi", setup_order=True)
    assert [n for n, _ in res] == ["web1", "control"]        # the main server last
    assert [k for k, _ in m.runs] == ["web1", None]
    assert m.runs[0][1].startswith("export LT_NODE=web1 LT_NODES='control web1'\n")
    assert "LT_SHARE_KEY=c2VjcmV0+/=" in m.runs[1][1]        # handed to the later server
    assert "c2VjcmV0" not in res[0][1].output                # and not kept in the output
    m = FakeLabs()
    assert [n for n, _ in m.run_on_nodes(1, extra, "x")] == ["control", "web1"]
    m = FakeLabs()                                           # one server: the script as it is
    m.run_on_nodes(1, {}, "echo hi", setup_order=True)
    assert m.runs == [(None, "echo hi")]
    assert not SHARE.search("@@LT SHARE KEY two words\n") and not SHARE.search("@@LT SHARE lower x\n")


@pytest.fixture(scope="module")
def mgr():
    m = LabManager()
    try:
        m.client.images.get("linux-training-base")
    except Exception:
        pytest.skip("Docker or the lab image linux-training-base is not available")
    return m


def test_two_server_lab(mgr):
    aid = 910000 + uuid.uuid4().int % 9999
    extra = {"nodes": [{"name": "lb", "image": "linux-training-base"}, {"name": "app1", "image": "linux-training-base"}]}
    try:
        mgr.create(LabSpec(attempt_id=aid, image="linux-training-base", cpu=0.5, memory_mb=256, pids_limit=256,
                           capabilities=[], tmpfs={}, nodes=extra["nodes"]))
        mgr.wait_all(aid, extra)
        # each server knows the other by its node name; the hostnames are the node names
        r = mgr.exec(aid, ["sh", "-c", "hostname; getent hosts app1 >/dev/null && echo found"])
        assert r.output.split() == ["lb", "found"], r.output
        assert mgr.exec(aid, ["hostname"], node="app1").output.strip() == "app1"
        res = dict(mgr.run_on_nodes(aid, extra, "echo $LT_NODE"))
        assert res["lb"].output.strip() == "lb" and res["app1"].output.strip() == "app1"
        hc = mgr.client.containers.get(mgr.name(aid, "app1")).attrs["HostConfig"]
        assert not hc["Privileged"] and hc["CapAdd"] in (["SYS_ADMIN"], ["CAP_SYS_ADMIN"])
        assert "/proc/sys" in (hc.get("ReadonlyPaths") or ["/proc/sys"])  # not nested: /proc/sys stays read-only
    finally:
        mgr.destroy(aid)
    assert not mgr.client.containers.list(all=True, filters={"label": f"lt.attempt={aid}"})
    assert not mgr.client.networks.list(names=[mgr.network_name(aid)])


def test_attempt_lists_its_servers(admin, client):
    from conftest import TECH_PW, login
    assert admin.post("/api/admin/scenarios/seed").status_code == 200
    scs = {s["slug"]: s for s in admin.get("/api/admin/scenarios").json()}
    assert scs["net-lb-backend"]["options"]["nodes"][1] == {"name": "app1", "image": "linux-training-web"}
    assert scs["docker-crash-loop"]["options"]["nested_containers"] is True
    admin.post("/api/auth/logout")
    tech = login(client, "tech", TECH_PW)
    a = tech.post("/api/attempts", json={"scenario_id": scs["net-lb-backend"]["id"]}).json()
    assert a["nodes"] == ["lb", "app1"]
    tech.post(f"/api/attempts/{a['id']}/abandon")
    a = tech.post("/api/attempts", json={"scenario_id": scs["nginx-config-syntax"]["id"]}).json()
    assert a["nodes"] == []
