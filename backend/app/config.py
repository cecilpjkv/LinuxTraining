"""Settings from the environment (no extra dependency: plain os.environ)."""
import os
import secrets


def _env(name: str, default: str | None = None) -> str:
    v = os.environ.get(name, default)
    if v is None:
        raise RuntimeError(f"environment variable {name} is required")
    return v


class Settings:
    def __init__(self) -> None:
        self.database_url = _env("LT_DATABASE_URL", "postgresql+psycopg://linuxtraining:linuxtraining@db:5432/linuxtraining")
        # the JWT key must be stable across restarts: set LT_SECRET_KEY in production (a random one logs everybody out
        # on every restart)
        self.secret_key = os.environ.get("LT_SECRET_KEY") or secrets.token_urlsafe(48)
        self.token_hours = int(_env("LT_TOKEN_HOURS", "12"))
        self.cookie_secure = _env("LT_COOKIE_SECURE", "false").lower() == "true"
        self.scenarios_dir = _env("LT_SCENARIOS_DIR", "/srv/scenarios")
        self.allow_registration = _env("LT_ALLOW_REGISTRATION", "true").lower() == "true"


settings = Settings()
