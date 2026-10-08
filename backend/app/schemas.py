from datetime import datetime

from pydantic import BaseModel, Field


class LoginIn(BaseModel):
    username: str = Field(min_length=1, max_length=255)  # username or e-mail
    password: str = Field(min_length=1, max_length=256)


class RegisterIn(BaseModel):
    username: str = Field(min_length=3, max_length=64, pattern=r"^[A-Za-z0-9_.-]+$")
    email: str | None = Field(default=None, max_length=255, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    full_name: str = Field(default="", max_length=128)
    password: str = Field(min_length=1, max_length=256)


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
