from app.db import SessionLocal
from app.models import Scenario, TrainingAttempt
from app.services.scheduler import Scheduler
from conftest import TECH_PW, login


def seed(admin):
    r = admin.post("/api/admin/scenarios/seed")
    assert r.status_code == 200 and "nginx-config-syntax" in r.json()["added"], r.text
    return next(s for s in admin.get("/api/admin/scenarios").json() if s["slug"] == "nginx-config-syntax")


def test_seed_once_and_admin_edits_survive(admin):
    sc = seed(admin)
    assert sc["version"] == 1 and "nginx -t" in sc["verify_script"]
    assert admin.post("/api/admin/scenarios/seed").json()["added"] == []  # never twice
    admin.delete(f"/api/admin/scenarios/{sc['id']}")
    assert admin.post("/api/admin/scenarios/seed").json()["added"] == []  # a deleted seed stays deleted


def test_versions_on_script_change(admin):
    sc = seed(admin)
    r = admin.patch(f"/api/admin/scenarios/{sc['id']}", json={"name": "Renamed"})
    assert r.json()["version"] == 1 and r.json()["name"] == "Renamed"  # metadata only: same version
    r = admin.patch(f"/api/admin/scenarios/{sc['id']}", json={"verify_script": sc["verify_script"] + "\n# v2\n"})
    assert r.json()["version"] == 2
    assert len(admin.get(f"/api/admin/scenarios/{sc['id']}/versions").json()) == 2
    assert admin.patch(f"/api/admin/scenarios/{sc['id']}", json={"score_yaml": "items: {}"}).status_code == 422
    assert admin.patch(f"/api/admin/scenarios/{sc['id']}", json={"resource_weight": 5}).status_code == 422  # max weight 4


def test_technician_sees_no_scripts(admin, client, make_user):
    seed(admin)
    admin.post("/api/auth/logout")
    tech = login(client, "tech", TECH_PW)
    s = tech.get("/api/scenarios").json()[0]
    assert "setup_script" not in s and "verify_script" not in s and "docker_image" not in s
    assert tech.get("/api/admin/scenarios").status_code == 403
    assert tech.post("/api/admin/scenarios/seed").status_code == 403


def test_queue_limits_and_one_attempt_per_user(admin, client, make_user, monkeypatch):
    sc = seed(admin)
    admin.post("/api/auth/logout")
    monkeypatch.setattr(Scheduler, "provision", lambda self, aid: None)  # no containers here: only the decision
    sched = Scheduler()
    for n in ("t1", "t2", "t3"):
        make_user(n)
    ids = []
    for n in ("t1", "t2", "t3"):
        c = login(client, n, TECH_PW)
        r = c.post("/api/attempts", json={"scenario_id": sc["id"]})
        assert r.status_code == 201 and r.json()["status"] == "queued"
        if n == "t1":
            assert c.post("/api/attempts", json={"scenario_id": sc["id"]}).status_code == 409  # one at a time
        ids.append(r.json()["id"])
        c.post("/api/auth/logout")
    assert sorted(sched.tick()) == ids[:2]  # weight 2 + 2 = 4: the third waits
    with SessionLocal() as db:
        st = {a.id: a.status for a in db.query(TrainingAttempt)}
    assert [st[i] for i in ids] == ["provisioning", "provisioning", "queued"]
    c = login(client, "t3", TECH_PW)
    assert c.get(f"/api/attempts/{ids[2]}").json()["queue_position"] == 1
    assert c.get(f"/api/attempts/{ids[0]}").status_code == 404  # not theirs
    c.post("/api/auth/logout")
    login(client, "t1", TECH_PW)
    with SessionLocal() as db:  # pretend the lab exists so abandon can end it (destroy of a missing container is fine)
        pass
    assert client.post(f"/api/attempts/{ids[0]}/abandon").json()["status"] == "abandoned"
    assert sched.tick() == [ids[2]]  # the slot went to the queued attempt


def test_settings_validation(admin):
    assert admin.put("/api/admin/settings", json={"max_concurrent_tests": 0}).status_code == 422
    assert admin.put("/api/admin/settings", json={"bogus": 1}).status_code == 422
    v = admin.put("/api/admin/settings", json={"max_concurrent_tests": 3, "lab_cpu": "0.75"}).json()["values"]
    assert v["max_concurrent_tests"] == 3 and v["lab_cpu"] == 0.75


def test_result_of_graded_attempt(admin, client):
    """Found end to end: a graded attempt's result failed (the score relationship was taken for the number)."""
    from app.models import Score
    sc = seed(admin)
    with SessionLocal() as db:
        a = TrainingAttempt(user_id=1, scenario_id=sc["id"], scenario_name="x", status="completed")
        db.add(a)
        db.flush()
        db.add(Score(attempt_id=a.id, total=80, maximum=100, passed=True, breakdown=[{"item": "a", "points": 80, "max": 100}]))
        db.commit()
        aid = a.id
    r = admin.get(f"/api/attempts/{aid}/result").json()
    assert r["score"] == 80 and r["percent"] == 80 and r["passed"] and r["breakdown"][0]["points"] == 80
