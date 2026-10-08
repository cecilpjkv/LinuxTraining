"""Completing an attempt (spec §11): stop the terminal, verify the final server state, collect it, score, store,
then destroy the lab. Used by "Complete Test" and by the time limit (graded the same way, status timed_out)."""
import logging
import threading

from sqlalchemy import update

from ..db import SessionLocal
from ..models import Command, LabContainer, Score, ScenarioVersion, TrainingAttempt, VerificationResult
from .lab_manager import labs
from .scheduler import now, scheduler
from .scoring import run_verify, score
from .terminal import terminals

log = logging.getLogger("grading")


def begin(attempt_id: int, final_status: str, reason: str) -> bool:
    """Moves a ready attempt to verifying (once: a second click or the timer racing a click does nothing) and grades
    it in the background."""
    with SessionLocal() as db:
        n = db.execute(update(TrainingAttempt).where(TrainingAttempt.id == attempt_id, TrainingAttempt.status == "ready")
                       .values(status="verifying")).rowcount
        db.commit()
    if n != 1:
        return False
    threading.Thread(target=grade, args=(attempt_id, final_status, reason), name=f"grade-{attempt_id}", daemon=True).start()
    return True


def grade(attempt_id: int, final_status: str = "completed", reason: str = "completed by the technician") -> None:
    terminals.close(attempt_id)  # no more input; the last commands are stored first
    with SessionLocal() as db:
        a = db.get(TrainingAttempt, attempt_id)
        v = db.get(ScenarioVersion, a.scenario_version_id) if a.scenario_version_id else None
        try:
            if not v:
                raise RuntimeError("the scenario version of this attempt no longer exists")
            r = run_verify(attempt_id, v.verify_script)
            history = [c.command for c in db.query(Command).filter_by(attempt_id=attempt_id).order_by(Command.id)]
            res = score(v.score_config, r.output, history)
            for item, cfg in v.score_config["items"].items():
                c = res["checks"].get(item)
                db.add(VerificationResult(attempt_id=a.id, check=item, label=cfg["label"], passed=bool(c and c["status"] == "PASS"),
                                          detail=(c["detail"] if c else "not reported by verify.sh")[:2000]))
            db.add(Score(attempt_id=a.id, total=res["total"], maximum=res["maximum"], passed=res["passed"],
                         breakdown=res["breakdown"], verify_output=_strip_markers(r.output)[-20000:]))
            a.final_state = collect_state(attempt_id, v.extra.get("collect", []))
            a.status, a.end_reason = final_status, reason
            if r.timed_out:
                a.error = "verify.sh hit its time limit; unreported checks scored 0"
        except Exception as e:
            log.error("attempt %s: grading failed: %s", attempt_id, e)
            a.status, a.end_reason, a.error = "failed", "grading failed", str(e)[:8000]
        a.ended_at = now()
        db.commit()  # everything is stored before the lab goes
        labs.destroy(attempt_id)
        lab = db.query(LabContainer).filter_by(attempt_id=attempt_id).one_or_none()
        if lab:
            lab.status, lab.destroyed_at = "destroyed", now()
        db.commit()
    scheduler.kick()


def collect_state(attempt_id: int, commands: list[str]) -> str:
    parts = []
    for c in commands:
        r = labs.exec(attempt_id, ["bash", "-c", c], timeout=20, max_output=16 * 1024)
        parts.append(f"$ {c}\n{r.output.rstrip()}\n[exit {r.exit_code}]")
    return "\n\n".join(parts)


def _strip_markers(s: str) -> str:
    return "\n".join(l for l in s.splitlines() if not l.startswith("@@LT ")) + "\n\n" + "\n".join(
        l for l in s.splitlines() if l.startswith("@@LT "))
