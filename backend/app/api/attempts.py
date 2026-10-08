from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import current_user
from ..models import Scenario, TrainingAttempt, User
from ..schemas import AttemptOut
from ..services import settings_store
from ..services.scheduler import ACTIVE, now, queue_position, scheduler
from pydantic import BaseModel

router = APIRouter(prefix="/api/attempts", tags=["attempts"])


def attempt_out(db: Session, a: TrainingAttempt, with_error: bool = False) -> AttemptOut:
    # explicit fields: "score" here is a number, on the model it is the Score relationship
    o = AttemptOut(**{k: getattr(a, k) for k in ("id", "scenario_id", "scenario_name", "status", "resource_weight", "created_at",
                                               "started_at", "deadline_at", "ended_at", "end_reason")})
    o.queue_position = queue_position(db, a)
    if a.score:
        o.score, o.max_score, o.passed = a.score.total, a.score.maximum, a.score.passed
        o.percent = round(100 * a.score.total / a.score.maximum, 1) if a.score.maximum else 0
    if a.scenario:
        o.description = a.scenario.description
    if not with_error and a.error:
        o.error = "the lab could not be prepared; please try again or tell an administrator"
    return o


def own(db: Session, aid: int, user: User) -> TrainingAttempt:
    a = db.get(TrainingAttempt, aid)
    if not a or (a.user_id != user.id and user.role != "admin"):
        raise HTTPException(404, "no such attempt")
    return a


class StartIn(BaseModel):
    scenario_id: int


@router.post("", response_model=AttemptOut, status_code=201)
def start(body: StartIn, db: Session = Depends(get_db), user: User = Depends(current_user)):
    sc = db.get(Scenario, body.scenario_id)
    if not sc or not sc.enabled or not sc.current_version_id:
        raise HTTPException(404, "no such scenario")
    busy = db.scalar(select(TrainingAttempt).where(TrainingAttempt.user_id == user.id, TrainingAttempt.status.in_((*ACTIVE, "queued"))))
    if busy:
        raise HTTPException(409, f"you already have an unfinished test (#{busy.id}); finish or abandon it first")
    if sc.resource_weight > settings_store.get_all(db)["max_resource_weight"]:
        raise HTTPException(409, "this scenario needs more resources than the server allows; tell an administrator")
    a = TrainingAttempt(user_id=user.id, scenario_id=sc.id, scenario_version_id=sc.current_version_id, scenario_name=sc.name,
                        resource_weight=sc.resource_weight, status="queued")
    db.add(a)
    db.commit()
    scheduler.kick()
    return attempt_out(db, a)


@router.get("", response_model=list[AttemptOut])
def mine(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = db.scalars(select(TrainingAttempt).where(TrainingAttempt.user_id == user.id).order_by(TrainingAttempt.id.desc()).limit(200))
    return [attempt_out(db, a) for a in rows]


@router.get("/{aid}", response_model=AttemptOut)
def get(aid: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    return attempt_out(db, own(db, aid, user), with_error=user.role == "admin")


@router.post("/{aid}/abandon", response_model=AttemptOut)
def abandon(aid: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    a = own(db, aid, user)
    if a.status not in (*ACTIVE, "queued"):
        raise HTTPException(409, f"the attempt is already {a.status}")
    from ..services.lifecycle import end_attempt
    end_attempt(db, a, "abandoned", "abandoned by the technician" if a.user_id == user.id else f"terminated by {user.username}")
    return attempt_out(db, a)


@router.post("/{aid}/complete", response_model=AttemptOut)
def complete(aid: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    a = own(db, aid, user)
    if a.user_id != user.id:
        raise HTTPException(403, "only the technician who runs the test can complete it")
    from ..services import grading
    if not grading.begin(a.id, "completed", "completed by the technician"):
        raise HTTPException(409, f"the attempt is {a.status}, not ready")
    db.refresh(a)
    return attempt_out(db, a)


@router.get("/{aid}/result")
def result(aid: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    """The technician's result: score, breakdown and checks (not the scripts)."""
    a = own(db, aid, user)
    out = attempt_out(db, a, with_error=user.role == "admin").model_dump()
    if a.score:
        out["breakdown"] = a.score.breakdown
        out["checks"] = [{"check": v.check, "label": v.label, "passed": v.passed} for v in a.verification_results]
    return out
