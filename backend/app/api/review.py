"""Admin review (spec §14-15): dashboard numbers, attempt lists, one attempt in full, technician statistics."""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import require_admin
from ..models import Command, Scenario, Score, ScenarioVersion, TrainingAttempt, User
from ..services import settings_store
from ..services.scheduler import ACTIVE, usage
from .attempts import attempt_out

router = APIRouter(prefix="/api/admin", tags=["admin"], dependencies=[Depends(require_admin)])

GRADED = ("completed", "timed_out")


@router.get("/dashboard")
def dashboard(db: Session = Depends(get_db)):
    cfg = settings_store.get_all(db)
    n_active, weight = usage(db)
    count = lambda *st: db.scalar(select(func.count()).select_from(TrainingAttempt).where(TrainingAttempt.status.in_(st)))
    graded = select(Score).join(TrainingAttempt).where(TrainingAttempt.status.in_(GRADED)).subquery()
    avg = db.scalar(select(func.avg(100.0 * graded.c.total / func.nullif(graded.c.maximum, 0))))
    not_passed = db.scalar(select(func.count()).select_from(graded).where(graded.c.passed.is_(False)))
    passed = db.scalar(select(func.count()).select_from(graded).where(graded.c.passed.is_(True)))
    return {
        "active": n_active, "max_active": cfg["max_concurrent_tests"], "weight": weight, "max_weight": cfg["max_resource_weight"],
        "queued": count("queued"), "completed": count(*GRADED), "passed": passed, "not_passed": not_passed,
        "errors": count("failed"), "abandoned": count("abandoned", "terminated"),
        "average_score": round(avg, 1) if avg is not None else None,
        "technicians": db.scalar(select(func.count()).select_from(User).where(User.role == "technician")),
        "scenarios": db.scalar(select(func.count()).select_from(Scenario)),
        "scenarios_enabled": db.scalar(select(func.count()).select_from(Scenario).where(Scenario.enabled.is_(True))),
    }


@router.get("/attempts")
def attempts(db: Session = Depends(get_db), status: str | None = None, user_id: int | None = None,
             scenario_id: int | None = None, result: str | None = Query(None, pattern="^(passed|not_passed|failed)$"),
             limit: int = Query(100, le=500), offset: int = 0):
    q = select(TrainingAttempt, User).join(User).order_by(TrainingAttempt.id.desc())
    if status:
        q = q.where(TrainingAttempt.status.in_(status.split(",")))
    if user_id:
        q = q.where(TrainingAttempt.user_id == user_id)
    if scenario_id:
        q = q.where(TrainingAttempt.scenario_id == scenario_id)
    if result == "passed":
        q = q.join(Score).where(Score.passed.is_(True))
    elif result == "not_passed":  # graded, below the pass mark ("failed tests")
        q = q.join(Score).where(Score.passed.is_(False))
    elif result == "failed":  # the lab or the grading itself failed
        q = q.where(TrainingAttempt.status == "failed")
    total = db.scalar(select(func.count()).select_from(q.order_by(None).subquery()))
    rows = db.execute(q.limit(limit).offset(offset)).all()
    return {"total": total, "items": [{**attempt_out(db, a, with_error=True).model_dump(), "username": u.username,
                                       "technician": u.full_name or u.username, "email": u.email,
                                       "commands": db.scalar(select(func.count()).select_from(Command).where(Command.attempt_id == a.id))}
                                      for a, u in rows]}


@router.get("/attempts/{aid}")
def review(aid: int, db: Session = Depends(get_db)):
    a = db.get(TrainingAttempt, aid)
    if not a:
        raise HTTPException(404, "no such attempt")
    v = db.get(ScenarioVersion, a.scenario_version_id) if a.scenario_version_id else None
    end = a.ended_at
    return {
        **attempt_out(db, a, with_error=True).model_dump(),
        "technician": {"id": a.user.id, "username": a.user.username, "full_name": a.user.full_name, "email": a.user.email},
        "scenario": {"id": a.scenario_id, "name": a.scenario_name, "category": a.scenario.category if a.scenario else None,
                     "difficulty": a.scenario.difficulty if a.scenario else None, "version": v.version if v else None},
        "duration_seconds": int((end - a.started_at).total_seconds()) if end and a.started_at else None,
        "commands": [{"at": c.at, "session": c.session_id, "command": c.command, "exit_code": c.exit_code, "cwd": c.cwd,
                      "output": c.output} for c in a.commands],
        "verification": [{"check": r.check, "label": r.label, "passed": r.passed, "detail": r.detail} for r in a.verification_results],
        "breakdown": a.score.breakdown if a.score else [],
        "verify_output": a.score.verify_output if a.score else "",
        "final_state": a.final_state,
        "error": a.error,
    }


@router.get("/technicians")
def technicians(db: Session = Depends(get_db)):
    pct = 100.0 * Score.total / func.nullif(Score.maximum, 0)
    stats = {uid: (n, avg, p) for uid, n, avg, p in db.execute(
        select(TrainingAttempt.user_id, func.count(Score.id), func.avg(pct), func.sum(func.cast(Score.passed, type_=__import__("sqlalchemy").Integer)))
        .join(Score, Score.attempt_id == TrainingAttempt.id).group_by(TrainingAttempt.user_id))}
    totals = dict(db.execute(select(TrainingAttempt.user_id, func.count()).group_by(TrainingAttempt.user_id)).all())
    out = []
    for u in db.scalars(select(User).where(User.role == "technician").order_by(User.username)):
        n, avg, p = stats.get(u.id, (0, None, 0))
        out.append({"id": u.id, "username": u.username, "full_name": u.full_name, "email": u.email, "active": u.active, "last_login_at": u.last_login_at,
                    "attempts": totals.get(u.id, 0), "graded": n, "passed": p or 0, "average_score": round(avg, 1) if avg is not None else None})
    return out
