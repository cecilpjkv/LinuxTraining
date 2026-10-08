from conftest import ADMIN_PW, TECH_PW, login


def test_health(client):
    assert client.get("/api/health").json() == {"status": "ok"}


def test_login_logout(client):
    assert client.get("/api/auth/me").status_code == 401
    r = client.post("/api/auth/login", json={"username": "admin", "password": ADMIN_PW})
    assert r.status_code == 200 and r.json()["role"] == "admin"
    assert "httponly" in r.headers["set-cookie"].lower() and "samesite=strict" in r.headers["set-cookie"].lower()
    assert client.get("/api/auth/me").json()["username"] == "admin"
    client.post("/api/auth/logout")
    assert client.get("/api/auth/me").status_code == 401


def test_login_by_email_and_wrong_password(client):
    assert client.post("/api/auth/login", json={"username": "TECH@example.com", "password": TECH_PW}).status_code == 200
    r = client.post("/api/auth/login", json={"username": "tech", "password": "nope"})
    assert r.status_code == 401 and r.json()["detail"] == "wrong username or password"
    assert client.post("/api/auth/login", json={"username": "ghost", "password": "nope"}).json()["detail"] == "wrong username or password"


def test_register_is_technician(client):
    r = client.post("/api/auth/register", json={"username": "newbie", "password": "long-enough-pw", "role": "admin"})
    assert r.status_code == 201 and r.json()["role"] == "technician"
    assert client.post("/api/auth/register", json={"username": "newbie", "password": "long-enough-pw"}).status_code == 409
    assert client.post("/api/auth/register", json={"username": "short", "password": "x"}).status_code == 422
    assert client.post("/api/auth/register", json={"username": "../bad", "password": "long-enough-pw"}).status_code == 422


def test_admin_only(tech):
    assert tech.get("/api/admin/users").status_code == 403


def test_admin_users(admin):
    users = admin.get("/api/admin/users").json()
    assert [u["username"] for u in users] == ["admin", "tech"]
    tid = next(u["id"] for u in users if u["username"] == "tech")
    assert admin.patch(f"/api/admin/users/{tid}", json={"active": False}).json()["active"] is False
    aid = next(u["id"] for u in users if u["username"] == "admin")
    assert admin.patch(f"/api/admin/users/{aid}", json={"role": "technician"}).status_code == 400


def test_disabled_user_cannot_login(admin, client):
    tid = next(u["id"] for u in admin.get("/api/admin/users").json() if u["username"] == "tech")
    admin.patch(f"/api/admin/users/{tid}", json={"active": False})
    admin.post("/api/auth/logout")
    assert client.post("/api/auth/login", json={"username": "tech", "password": TECH_PW}).status_code == 401


def test_tampered_token(client):
    client.cookies.set("lt_session", "eyJhbGciOiJub25lIn0.eyJzdWIiOiIxIn0.")
    assert client.get("/api/auth/me").status_code == 401


def test_login_throttle(client):
    import app.api.auth as auth
    auth._FAILS.clear()
    for _ in range(10):
        assert client.post("/api/auth/login", json={"username": "victim", "password": "x"}).status_code == 401
    assert client.post("/api/auth/login", json={"username": "victim", "password": "x"}).status_code == 429
    auth._FAILS.clear()


def test_session_endpoint(client):
    assert client.get("/api/auth/session").json() == {"user": None}
    client.post("/api/auth/login", json={"username": "admin", "password": ADMIN_PW})
    assert client.get("/api/auth/session").json()["user"]["username"] == "admin"
