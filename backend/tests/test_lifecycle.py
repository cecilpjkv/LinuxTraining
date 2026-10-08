import uuid
from datetime import datetime, timedelta, timezone

import pytest

from app.db import SessionLocal
from app.models import TrainingAttempt, User
from app.services.scheduler import Scheduler


def mk(status, **kw):
    with SessionLocal() as db:
        u = db.query(User).filter_by(username="tech").one()
        a = TrainingAttempt(user_id=u.id, scenario_name="s", status=status, **kw)
        db.add(a)
        db.commit()
        return a.id


def status(aid):
    with SessionLocal() as db:
        a = db.get(TrainingAttempt, aid)
        return a.status, a.end_reason


T = lambda **kw: datetime.now(timezone.utc) - timedelta(**kw)


def test_time_limit_grades(monkeypatch):
    import app.services.grading as g
    calls = []
    monkeypatch.setattr(g, "begin", lambda aid, st, why: calls.append((aid, st)) or True)
    aid = mk("ready", started_at=T(minutes=31), deadline_at=T(minutes=1), last_seen_at=T(seconds=5))
    Scheduler().maintain()
    assert calls == [(aid, "timed_out")]


def test_idle_lab_abandoned():
    aid = mk("ready", started_at=T(minutes=30), deadline_at=T(minutes=-30))  # never attached, idle limit 20 min
    Scheduler().maintain()
    assert status(aid) == ("abandoned", "no terminal connected for 20 minutes")


def test_recent_lab_kept():
    aid = mk("ready", started_at=T(minutes=5), deadline_at=T(minutes=-25))
    Scheduler().maintain()
    assert status(aid)[0] == "ready"


def test_interrupted_provisioning_requeued():
    aid = mk("provisioning", started_at=T(minutes=15))
    Scheduler().maintain()
    assert status(aid)[0] == "queued"


def test_old_queue_entry_expires():
    aid = mk("queued", created_at=T(hours=7))
    Scheduler().maintain()
    assert status(aid) == ("abandoned", "waited in the queue for more than 6 hours")


def test_orphan_container_removed(monkeypatch):
    from app.services.lab_manager import LabManager, LabSpec
    import app.services.scheduler as sch
    m = LabManager()
    try:
        m.client.images.get("linux-training-base")
    except Exception:
        pytest.skip("no Docker / lab image")
    monkeypatch.setattr(sch, "labs", m)
    aid = 700000 + uuid.uuid4().int % 99999  # no attempt row: an orphan
    m.create(LabSpec(attempt_id=aid, image="linux-training-base", cpu=0.2, memory_mb=128, pids_limit=128, capabilities=[], tmpfs={}))
    assert m.running(aid)
    assert Scheduler().remove_orphans() >= 1
    assert not m.running(aid)


def test_lab_daemon_is_userns_remapped():
    from app.services.lab_manager import LabManager
    m = LabManager()
    try:
        opts = m.client.info().get("SecurityOptions", [])
    except Exception:
        pytest.skip("no Docker")
    assert any("userns" in o for o in opts), opts
