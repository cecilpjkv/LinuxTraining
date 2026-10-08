"""Scheduler (spec §6): decides when a queued attempt may start and provisions it.

A lab starts only when BOTH hold: active labs < max_concurrent_tests, and active weight + its weight <=
max_resource_weight. Otherwise the attempt waits in the queue; whenever a lab ends, the oldest queued attempt that
fits starts (a heavy one at the head does not block lighter ones behind it forever: see pick()). Decisions are made
under a PostgreSQL advisory lock, so two requests can never both take the last slot.

Runs inside the single backend process (one uvicorn worker) as a background thread; no Redis/Celery.
"""
import logging
import threading
import traceback
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, text
from sqlalchemy.orm import Session

from ..db import SessionLocal
from ..models import LabContainer, ScenarioVersion, TrainingAttempt
from . import settings_store
from .lab_manager import LabSpec, labs

log = logging.getLogger("scheduler")

ACTIVE = ("provisioning", "ready", "verifying")
ENDED = ("completed", "failed", "timed_out", "abandoned", "terminated")
LOCK_ID = 727274  # pg_advisory_xact_lock key for scheduling decisions


def now() -> datetime:
    return datetime.now(timezone.utc)


def usage(db: Session) -> tuple[int, int]:
    rows = db.execute(select(TrainingAttempt.resource_weight).where(TrainingAttempt.status.in_(ACTIVE))).scalars().all()
    return len(rows), sum(rows)


def pick(queued: list[TrainingAttempt], active: int, weight: int, max_n: int, max_w: int) -> list[TrainingAttempt]:
    """The queued attempts that can start now, oldest first; an attempt that does not fit is skipped, the ones behind
    it may still start (FIFO among those that fit)."""
    out = []
    for a in queued:
        if active >= max_n:
            break
        if weight + a.resource_weight <= max_w:
            out.append(a)
            active += 1
            weight += a.resource_weight
    return out


def queue_position(db: Session, attempt: TrainingAttempt) -> int | None:
    if attempt.status != "queued":
        return None
    ids = db.execute(select(TrainingAttempt.id).where(TrainingAttempt.status == "queued").order_by(TrainingAttempt.created_at, TrainingAttempt.id)).scalars().all()
    return ids.index(attempt.id) + 1 if attempt.id in ids else None


class Scheduler:
    def __init__(self) -> None:
        self._wake = threading.Event()
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self.tick_seconds = 5.0

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._run, name="scheduler", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        self._wake.set()

    def kick(self) -> None:
        self._wake.set()

    def _run(self) -> None:
        while not self._stop.is_set():
            try:
                self.tick()
            except Exception:  # never let the loop die
                log.error("scheduler tick failed:\n%s", traceback.format_exc())
            self._wake.wait(self.tick_seconds)
            self._wake.clear()

    def tick(self) -> list[int]:
        """One round: start what fits (and, from phase 6, time out and clean up). Returns the attempts started."""
        started = []
        with SessionLocal() as db:
            db.execute(text("SELECT pg_advisory_xact_lock(:k)"), {"k": LOCK_ID})
            cfg = settings_store.get_all(db)
            active, weight = usage(db)
            queued = db.execute(select(TrainingAttempt).where(TrainingAttempt.status == "queued")
                                .order_by(TrainingAttempt.created_at, TrainingAttempt.id)).scalars().all()
            for a in pick(queued, active, weight, cfg["max_concurrent_tests"], cfg["max_resource_weight"]):
                a.status, a.started_at = "provisioning", now()
                started.append(a.id)
            db.commit()  # releases the lock: the slots are taken
        for aid in started:
            threading.Thread(target=self.provision, args=(aid,), name=f"provision-{aid}", daemon=True).start()
        return started

    def provision(self, attempt_id: int) -> None:
        """Creates the lab, waits for systemd, runs setup.sh, confirms the scenario is broken, then opens it."""
        with SessionLocal() as db:
            a = db.get(TrainingAttempt, attempt_id)
            v = db.get(ScenarioVersion, a.scenario_version_id) if a and a.scenario_version_id else None
            if not a or a.status != "provisioning" or not v:
                return
            cfg = settings_store.get_all(db)
            sc = a.scenario
            lab = LabContainer(attempt_id=a.id, container_name=labs.name(a.id), image=sc.docker_image, cpu=cfg["lab_cpu"],
                               memory_mb=cfg["lab_memory_mb"])
            db.add(lab)
            db.commit()
            try:
                lab.container_id = labs.create(LabSpec(attempt_id=a.id, image=sc.docker_image, cpu=cfg["lab_cpu"],
                                                       memory_mb=cfg["lab_memory_mb"], pids_limit=cfg["lab_pids_limit"],
                                                       capabilities=v.extra.get("capabilities", []), tmpfs=v.extra.get("tmpfs", {})))
                lab.status = "running"
                db.commit()
                labs.wait_ready(a.id)
                r = labs.run_script(a.id, v.setup_script, timeout=300)
                if r.exit_code != 0:
                    raise RuntimeError(f"setup.sh failed (exit {r.exit_code}):\n{r.output[-4000:]}")
                from .scoring import confirm_broken  # local import: scoring imports this module's helpers
                ok, why = confirm_broken(a.id, v)
                if not ok:
                    raise RuntimeError(f"the scenario's problem was not in place after setup.sh: {why}")
                a.status = "ready"
                minutes = min(sc.time_limit, cfg["max_test_minutes"])
                a.deadline_at = now() + timedelta(minutes=minutes)
                db.commit()
                log.info("attempt %s ready (%s, %d min)", a.id, sc.slug, minutes)
            except Exception as e:  # the lab could not be prepared: record why, free the slot
                log.error("attempt %s: provisioning failed: %s", attempt_id, e)
                a.status, a.ended_at, a.end_reason = "failed", now(), "lab could not be prepared"
                a.error = str(e)[:8000]
                labs.destroy(a.id)
                lab.status, lab.destroyed_at = "destroyed", now()
                db.commit()
                self.kick()


scheduler = Scheduler()
