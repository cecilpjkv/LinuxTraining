from datetime import datetime

from pydantic import BaseModel, Field


class LoginIn(BaseModel):
    username: str = Field(min_length=1, max_length=255)  # username or e-mail
    password: str = Field(min_length=1, max_length=256)


class TechnicianIn(BaseModel):
    full_name: str = Field(min_length=2, max_length=128)
    email: str = Field(max_length=255, pattern=r"^\s*[^@\s]+@[^@\s]+\.[^@\s]+\s*$")


class UserOut(BaseModel):
    id: int
    username: str
    email: str | None
    full_name: str
    role: str
    active: bool
    created_at: datetime
    last_login_at: datetime | None

    model_config = {"from_attributes": True}


class UserUpdate(BaseModel):
    role: str | None = Field(default=None, pattern=r"^(admin|technician)$")
    active: bool | None = None
    full_name: str | None = Field(default=None, max_length=128)


class ScenarioOut(BaseModel):
    """What a technician sees: no scripts, no scoring internals."""
    id: int
    slug: str
    name: str
    description: str
    category: str
    difficulty: str
    time_limit: int
    resource_weight: int

    model_config = {"from_attributes": True}


class ScenarioAdminOut(ScenarioOut):
    docker_image: str
    pass_score: int
    enabled: bool
    created_at: datetime
    updated_at: datetime
    version: int | None = None
    setup_script: str = ""
    verify_script: str = ""
    score_yaml: str = ""
    options: dict = {}


class ScenarioIn(BaseModel):
    slug: str = Field(min_length=2, max_length=63, pattern=r"^[a-z0-9][a-z0-9-]{1,62}$")
    name: str = Field(min_length=1, max_length=200)
    description: str = Field(default="", max_length=20000)
    category: str
    difficulty: str
    docker_image: str
    time_limit: int
    resource_weight: int
    enabled: bool = True
    setup_script: str
    verify_script: str
    score_yaml: str
    options: dict = {}  # capabilities, tmpfs, collect


class ScenarioPatch(BaseModel):
    name: str | None = Field(default=None, max_length=200)
    description: str | None = Field(default=None, max_length=20000)
    category: str | None = None
    difficulty: str | None = None
    docker_image: str | None = None
    time_limit: int | None = None
    resource_weight: int | None = None
    enabled: bool | None = None
    setup_script: str | None = None
    verify_script: str | None = None
    score_yaml: str | None = None
    options: dict | None = None


class AttemptOut(BaseModel):
    id: int
    scenario_id: int | None
    scenario_name: str
    status: str
    resource_weight: int
    created_at: datetime
    started_at: datetime | None
    deadline_at: datetime | None
    ended_at: datetime | None
    end_reason: str
    queue_position: int | None = None
    score: float | None = None
    max_score: float | None = None
    percent: float | None = None
    passed: bool | None = None
    description: str = ""
    error: str = ""

    model_config = {"from_attributes": True}
