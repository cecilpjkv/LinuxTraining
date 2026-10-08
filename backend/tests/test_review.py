from datetime import datetime, timedelta, timezone

from app.db import SessionLocal
from app.models import Command, Score, TrainingAttempt, User, VerificationResult
from conftest import TECH_PW, login


def make(db, user, status, total=None, passed=None, name="S"):
    t = datetime.now(timezone.utc)
    a = TrainingAttempt(user_id=user.id, scenario_name=name, status=status, started_at=t - timedelta(minutes=12), ended_at=t)
    db.add(a)
    db.flush()
    if total is not None:
        db.add(Score(attempt_id=a.id, total=total, maximum=100, passed=passed, breakdown=[{"item": "x", "label": "X", "points": total, "max": 100, "kind": "state"}]))
    return a


def test_dashboard_review_and_stats(admin):
    with SessionLocal() as db:
        tech = db.query(User).filter_by(username="tech").one()
        a1 = make(db, tech, "completed", 90, True)
        make(db, tech, "completed", 40, False)
        make(db, tech, "failed")
        make(db, tech, "queued")
        db.add_all([Command(attempt_id=a1.id, session_id="s1", command="systemctl status nginx", exit_code=3, output="inactive"),
                    Command(attempt_id=a1.id, session_id="s1", command="systemctl start nginx", exit_code=0)])
        db.add(VerificationResult(attempt_id=a1.id, check="nginx_running", label="Nginx running", passed=True, detail=""))
        a1.final_state = "$ nginx -t\nok"
        db.commit()
        aid = a1.id
    d = admin.get("/api/admin/dashboard").json()
    assert (d["completed"], d["passed"], d["not_passed"], d["errors"], d["queued"], d["average_score"], d["technicians"]) == (2, 1, 1, 1, 1, 65.0, 1)
    r = admin.get(f"/api/admin/attempts/{aid}").json()
    assert r["technician"]["username"] == "tech" and r["duration_seconds"] == 720 and r["percent"] == 90
    assert [c["command"] for c in r["commands"]] == ["systemctl status nginx", "systemctl start nginx"]
    assert r["verification"][0]["passed"] and r["final_state"].startswith("$ nginx -t")
    assert admin.get("/api/admin/attempts?result=not_passed").json()["total"] == 1
    assert admin.get("/api/admin/attempts?result=failed").json()["total"] == 1
    assert admin.get("/api/admin/attempts?status=queued").json()["total"] == 1
    t = admin.get("/api/admin/technicians").json()[0]
    assert (t["attempts"], t["graded"], t["passed"], t["average_score"]) == (4, 2, 1, 65.0)


def test_review_is_admin_only(tech):
    assert tech.get("/api/admin/dashboard").status_code == 403
    assert tech.get("/api/admin/attempts").status_code == 403
    assert tech.get("/api/admin/attempts/1").status_code == 403
