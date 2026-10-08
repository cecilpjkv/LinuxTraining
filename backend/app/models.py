"""Database models (spec §18). Attempts keep everything needed for review after the lab is gone."""
from datetime import datetime, timezone

from sqlalchemy import JSON, Boolean, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base


def now() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    email: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)
    full_name: Mapped[str] = mapped_column(String(128), default="")
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(16), default="technician")  # admin | technician
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    attempts: Mapped[list["TrainingAttempt"]] = relationship(back_populates="user")


class Scenario(Base):
    __tablename__ = "scenarios"
    id: Mapped[int] = mapped_column(primary_key=True)
    slug: Mapped[str] = mapped_column(String(64), unique=True, index=True)  # directory name of the package
    name: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text, default="")
    category: Mapped[str] = mapped_column(String(32), index=True)
    difficulty: Mapped[str] = mapped_column(String(16))  # easy | intermediate | advanced | extra-hard
    docker_image: Mapped[str] = mapped_column(String(128))
    time_limit: Mapped[int] = mapped_column(Integer, default=30)  # minutes
    resource_weight: Mapped[int] = mapped_column(Integer, default=1)
    pass_score: Mapped[int] = mapped_column(Integer, default=70)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    current_version_id: Mapped[int | None] = mapped_column(ForeignKey("scenario_versions.id", use_alter=True, name="fk_scenarios_current_version"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, onupdate=now)

    versions: Mapped[list["ScenarioVersion"]] = relationship(back_populates="scenario", foreign_keys="ScenarioVersion.scenario_id",
                                                             cascade="all, delete-orphan")
    current_version: Mapped["ScenarioVersion | None"] = relationship(foreign_keys=[current_version_id], post_update=True)


class ScenarioVersion(Base):
    """An immutable snapshot of a scenario's scripts and scoring: attempts point at the version they ran, so editing a
    scenario never changes how an old attempt is reviewed."""
    __tablename__ = "scenario_versions"
    id: Mapped[int] = mapped_column(primary_key=True)
    scenario_id: Mapped[int] = mapped_column(ForeignKey("scenarios.id", ondelete="CASCADE"), index=True)
    version: Mapped[int] = mapped_column(Integer)
    setup_script: Mapped[str] = mapped_column(Text)
    verify_script: Mapped[str] = mapped_column(Text)
    score_config: Mapped[dict] = mapped_column(JSON)
    extra: Mapped[dict] = mapped_column(JSON, default=dict)  # options from scenario.yaml (capabilities, ports …)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    created_by: Mapped[str] = mapped_column(String(64), default="seed")
    __table_args__ = (UniqueConstraint("scenario_id", "version"),)

    scenario: Mapped[Scenario] = relationship(back_populates="versions", foreign_keys=[scenario_id])


class TrainingAttempt(Base):
    __tablename__ = "training_attempts"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    scenario_id: Mapped[int | None] = mapped_column(ForeignKey("scenarios.id", ondelete="SET NULL"), index=True, nullable=True)
    scenario_version_id: Mapped[int | None] = mapped_column(ForeignKey("scenario_versions.id", ondelete="SET NULL"), nullable=True)
    scenario_name: Mapped[str] = mapped_column(String(200), default="")  # kept if the scenario is deleted
    # queued -> provisioning -> ready -> verifying -> completed | failed | timed_out | abandoned | terminated
    status: Mapped[str] = mapped_column(String(16), index=True, default="queued")
    resource_weight: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deadline_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    end_reason: Mapped[str] = mapped_column(String(200), default="")
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)  # a terminal was attached
    final_state: Mapped[str] = mapped_column(Text, default="")  # relevant configuration/state collected at the end
    error: Mapped[str] = mapped_column(Text, default="")

    user: Mapped[User] = relationship(back_populates="attempts")
    scenario: Mapped[Scenario | None] = relationship()
    commands: Mapped[list["Command"]] = relationship(back_populates="attempt", order_by="Command.id", cascade="all, delete-orphan")
    verification_results: Mapped[list["VerificationResult"]] = relationship(back_populates="attempt", cascade="all, delete-orphan")
    score: Mapped["Score | None"] = relationship(back_populates="attempt", uselist=False, cascade="all, delete-orphan")
    lab: Mapped["LabContainer | None"] = relationship(back_populates="attempt", uselist=False)


class Command(Base):
    __tablename__ = "commands"
    id: Mapped[int] = mapped_column(primary_key=True)
    attempt_id: Mapped[int] = mapped_column(ForeignKey("training_attempts.id", ondelete="CASCADE"), index=True)
    session_id: Mapped[str] = mapped_column(String(32))
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    command: Mapped[str] = mapped_column(Text)
    output: Mapped[str] = mapped_column(Text, default="")  # truncated
    exit_code: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cwd: Mapped[str] = mapped_column(String(512), default="")

    attempt: Mapped[TrainingAttempt] = relationship(back_populates="commands")


class VerificationResult(Base):
    __tablename__ = "verification_results"
    id: Mapped[int] = mapped_column(primary_key=True)
    attempt_id: Mapped[int] = mapped_column(ForeignKey("training_attempts.id", ondelete="CASCADE"), index=True)
    check: Mapped[str] = mapped_column(String(64))
    label: Mapped[str] = mapped_column(String(200), default="")
    passed: Mapped[bool] = mapped_column(Boolean)
    detail: Mapped[str] = mapped_column(Text, default="")

    attempt: Mapped[TrainingAttempt] = relationship(back_populates="verification_results")


class Score(Base):
    __tablename__ = "scores"
    id: Mapped[int] = mapped_column(primary_key=True)
    attempt_id: Mapped[int] = mapped_column(ForeignKey("training_attempts.id", ondelete="CASCADE"), unique=True)
    total: Mapped[float] = mapped_column(Float)
    maximum: Mapped[float] = mapped_column(Float)
    passed: Mapped[bool] = mapped_column(Boolean)
    breakdown: Mapped[list] = mapped_column(JSON, default=list)  # [{item, label, points, max, reason}]
    verify_output: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)

    attempt: Mapped[TrainingAttempt] = relationship(back_populates="score")


class SystemSetting(Base):
    __tablename__ = "system_settings"
    key: Mapped[str] = mapped_column(String(64), primary_key=True)
    value: Mapped[str] = mapped_column(Text)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, onupdate=now)


class LabContainer(Base):
    __tablename__ = "lab_containers"
    id: Mapped[int] = mapped_column(primary_key=True)
    attempt_id: Mapped[int] = mapped_column(ForeignKey("training_attempts.id", ondelete="CASCADE"), unique=True)
    container_name: Mapped[str] = mapped_column(String(64), unique=True)
    container_id: Mapped[str] = mapped_column(String(80), default="")
    image: Mapped[str] = mapped_column(String(128))
    cpu: Mapped[float] = mapped_column(Float)
    memory_mb: Mapped[int] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(16), default="creating")  # creating | running | destroyed | error
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    destroyed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    attempt: Mapped[TrainingAttempt] = relationship(back_populates="lab")
