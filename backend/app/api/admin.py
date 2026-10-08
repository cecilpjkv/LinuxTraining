from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import require_admin
from ..models import LabContainer, TrainingAttempt, User
from ..services import settings_store
from ..services.scheduler import ACTIVE, queue_position, usage
from .attempts import attempt_out

router = APIRouter(prefix="/api/admin", tags=["admin"], dependencies=[Depends(require_admin)])


@router.get("/settings")
def get_settings(db: Session = Depends(get_db)):
    return {"values": settings_store.get_all(db), "fields": settings_store.describe()}


@router.put("/settings")
def put_settings(body: dict, db: Session = Depends(get_db)):
    try:
        values = settings_store.update(db, body)
    except ValueError as e:
        raise HTTPException(422, str(e))
    from ..services.scheduler import scheduler
    scheduler.kick()  # a higher limit may let queued attempts start
    return {"values": values, "fields": settings_store.describe()}


@router.get("/labs")
def active_labs(db: Session = Depends(get_db)):
    cfg = settings_store.get_all(db)
    n, w = usage(db)
    rows = db.execute(select(TrainingAttempt, User).join(User).where(TrainingAttempt.status.in_((*ACTIVE, "queued")))
                      .order_by(TrainingAttempt.created_at)).all()
    labs = []
    for a, u in rows:
        lab = db.scalar(select(LabContainer).where(LabContainer.attempt_id == a.id))
        labs.append({**attempt_out(db, a, with_error=True).model_dump(), "username": u.username,
                     "technician": u.full_name or u.username, "email": u.email,
                     "container": lab.container_name if lab else None, "queue_position": queue_position(db, a)})
    return {"active": n, "max_active": cfg["max_concurrent_tests"], "weight": w, "max_weight": cfg["max_resource_weight"],
            "labs": labs}


@router.post("/attempts/{aid}/terminate")
def terminate(aid: int, db: Session = Depends(get_db), admin: User = Depends(require_admin)):
    a = db.get(TrainingAttempt, aid)
    if not a:
        raise HTTPException(404, "no such attempt")
    if a.status not in (*ACTIVE, "queued"):
        raise HTTPException(409, f"the attempt is already {a.status}")
    from ..services.lifecycle import end_attempt
    end_attempt(db, a, "terminated", f"terminated by administrator {admin.username}")
    return attempt_out(db, a, with_error=True)
