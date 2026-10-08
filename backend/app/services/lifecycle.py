"""Ending an attempt without grading (abandon, admin terminate, timeout without completion): record why, then destroy
the lab and free its slot. Grading (complete) lives in grading.py."""
from sqlalchemy.orm import Session

from ..models import LabContainer, TrainingAttempt
from .lab_manager import labs
from .scheduler import now, scheduler


def end_attempt(db: Session, a: TrainingAttempt, status: str, reason: str) -> None:
    from .terminal import terminals
    terminals.close(a.id)
    a.status, a.ended_at, a.end_reason = status, now(), reason
    db.commit()  # saved before the lab goes
    labs.destroy(a.id)
    lab = db.query(LabContainer).filter_by(attempt_id=a.id).one_or_none()
    if lab and lab.status != "destroyed":
        lab.status, lab.destroyed_at = "destroyed", now()
    db.commit()
    scheduler.kick()
