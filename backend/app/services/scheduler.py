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
        self._busy: set[int] = set()  # attempts being provisioned by this process
        self._verifying_seen: dict[int, datetime] = {}
        self._last_orphans = datetime.min.replace(tzinfo=timezone.utc)

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
        """One round: housekeeping (time limits, idle labs, stuck states, orphans), then start what fits. Returns
        the attempts started."""
        try:
            self.maintain()
        except Exception:
            log.error("maintenance failed:\n%s", traceback.format_exc())
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

    # --- phase 6: lifecycle housekeeping ---

    STUCK_PROVISIONING = timedelta(minutes=10)
    QUEUE_EXPIRY = timedelta(hours=6)
    ORPHAN_EVERY = timedelta(minutes=5)

    def maintain(self) -> None:
        from .grading import begin, grade
        from .lifecycle import end_attempt
        from .terminal import terminals
        t = now()
        with SessionLocal() as db:
            cfg = settings_store.get_all(db)
            for a in db.execute(select(TrainingAttempt).where(TrainingAttempt.status.in_((*ACTIVE, "queued")))).scalars().all():
                if a.status == "ready":
                    if terminals.attached(a.id):
                        a.last_seen_at = t
                        db.commit()
                    if a.deadline_at and t >= a.deadline_at:
                        log.info("attempt %s: time limit reached, grading", a.id)
                        begin(a.id, "timed_out", "time limit reached: graded as it stood")
                    elif t - (a.last_seen_at or a.started_at or t) > timedelta(minutes=cfg["idle_abandon_minutes"]):
                        log.info("attempt %s: no terminal for %s min, abandoned", a.id, cfg["idle_abandon_minutes"])
                        end_attempt(db, a, "abandoned", f"no terminal connected for {cfg['idle_abandon_minutes']} minutes")
                elif a.status == "provisioning" and a.started_at and t - a.started_at > self.STUCK_PROVISIONING and a.id not in self._busy:
                    # the backend restarted while preparing it: start over from the queue
                    log.warning("attempt %s: provisioning interrupted, queued again", a.id)
                    labs.destroy(a.id)
                    db.query(LabContainer).filter_by(attempt_id=a.id).delete()
                    a.status, a.started_at = "queued", None
                    db.commit()
                elif a.status == "verifying" and not self._grading_alive(a.id) and \
                        t - self._verifying_seen.setdefault(a.id, t) > timedelta(minutes=1):
                    # no grading thread in this process for over a minute: it was interrupted (backend restart)
                    self._verifying_seen.pop(a.id, None)
                    log.warning("attempt %s: grading interrupted, grading again", a.id)
                    if labs.running(a.id):
                        threading.Thread(target=grade, args=(a.id, "completed", "completed (graded after a restart)"), daemon=True).start()
                    else:
                        end_attempt(db, a, "failed", "the lab was lost before grading")
                elif a.status == "queued" and t - a.created_at > self.QUEUE_EXPIRY:
                    end_attempt(db, a, "abandoned", "waited in the queue for more than 6 hours")
        if t - self._last_orphans > self.ORPHAN_EVERY:
            self._last_orphans = t
            self.remove_orphans()

    def _grading_alive(self, aid: int) -> bool:
        return any(th.name == f"grade-{aid}" and th.is_alive() for th in threading.enumerate())

    def remove_orphans(self) -> int:
        """Lab containers whose attempt is no longer running (crash, manual edits) are destroyed; a lab record whose
        container vanished is marked destroyed."""
        n = 0
        with SessionLocal() as db:
            live = set(db.execute(select(TrainingAttempt.id).where(TrainingAttempt.status.in_(ACTIVE))).scalars())
            for c in labs.managed():
                try:
                    aid = int(c["attempt"])
                except (TypeError, ValueError):
                    aid = None
                if aid not in live:
                    log.warning("removing orphan lab container %s", c["name"])
                    labs.destroy(aid) if aid is not None else None
                    n += 1
            for lab in db.query(LabContainer).filter(LabContainer.status != "destroyed").all():
                if lab.attempt_id not in live:
                    lab.status, lab.destroyed_at = "destroyed", now()
            db.commit()
        return n

    def provision(self, attempt_id: int) -> None:
        self._busy.add(attempt_id)
        try:
            self._provision(attempt_id)
        finally:
            self._busy.discard(attempt_id)

    def _provision(self, attempt_id: int) -> None:
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
