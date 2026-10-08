import os

import pytest
from fastapi.testclient import TestClient

# Always a separate database: the suite drops and recreates every table. Found on the first run: the container's
# LT_DATABASE_URL (the real database) won over a default, and the tests wiped it. The test URL is the real one with
# "_test" appended to the database name, or LT_TEST_DATABASE_URL; anything not ending in "_test" is refused.
_url = os.environ.get("LT_TEST_DATABASE_URL") or (os.environ.get("LT_DATABASE_URL", "postgresql+psycopg://linuxtraining:linuxtraining@db:5432/linuxtraining") + "_test")
if not _url.rsplit("/", 1)[-1].split("?")[0].endswith("_test"):
    raise SystemExit(f"refusing to run the tests against {_url!r}: the database name must end in _test")
os.environ["LT_DATABASE_URL"] = _url
os.environ["LT_SECRET_KEY"] = "test-secret"
os.environ["LT_DISABLE_SCHEDULER"] = "1"

from app.db import Base, SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.models import User  # noqa: E402
from app.security import hash_password  # noqa: E402

ADMIN_PW = "admin-password-1"
TECH_PW = "tech-password-1"


@pytest.fixture(autouse=True)
def fresh_db():
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        db.add_all([User(username="admin", role="admin", password_hash=hash_password(ADMIN_PW)),
                    User(username="tech", email="tech@example.com", role="technician", password_hash=hash_password(TECH_PW))])
        db.commit()
    yield


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


def login(c: TestClient, username: str, password: str) -> TestClient:
    r = c.post("/api/auth/login", json={"username": username, "password": password})
    assert r.status_code == 200, r.text
    return c


@pytest.fixture
def admin(client):
    return login(client, "admin", ADMIN_PW)


@pytest.fixture
def tech(client):
    return login(client, "tech", TECH_PW)


@pytest.fixture
def make_user():
    def mk(name: str, role: str = "technician", password: str = TECH_PW):
        with SessionLocal() as db:
            db.add(User(username=name, role=role, password_hash=hash_password(password)))
            db.commit()
    return mk
