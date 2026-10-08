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


def test_technician_name_and_email(client):
    r = client.post("/api/auth/technician", json={"full_name": "  Jane   Doe ", "email": " Jane.Doe@Example.com "})
    assert r.status_code == 200, r.text
    u = r.json()
    assert u["role"] == "technician" and u["email"] == "jane.doe@example.com" and u["full_name"] == "Jane Doe"
    assert u["username"] == "jane.doe"
    assert client.get("/api/auth/me").json()["id"] == u["id"]
    client.post("/api/auth/logout")
    # the same address continues as the same technician (name updated), no password involved
    again = client.post("/api/auth/technician", json={"full_name": "Jane D.", "email": "jane.doe@example.com"}).json()
    assert again["id"] == u["id"] and again["full_name"] == "Jane D."
    # a technician has no password to log in with
    assert client.post("/api/auth/login", json={"username": "jane.doe", "password": "!"}).status_code == 401


def test_technician_entry_validation(client, admin):
    assert client.post("/api/auth/technician", json={"full_name": "X", "email": "x@example.com"}).status_code == 422
    assert client.post("/api/auth/technician", json={"full_name": "No Mail", "email": "not-an-email"}).status_code == 422
    # an administrator's address cannot be used to enter as a technician
    aid = next(u["id"] for u in admin.get("/api/admin/users").json() if u["username"] == "admin")
    from app.db import SessionLocal
    from app.models import User
    with SessionLocal() as db:
        db.get(User, aid).email = "boss@example.com"
        db.commit()
    r = client.post("/api/auth/technician", json={"full_name": "Boss", "email": "boss@example.com"})
    assert r.status_code == 403
    # usernames stay unique when local parts collide
    a = client.post("/api/auth/technician", json={"full_name": "Sam One", "email": "sam@one.example"}).json()
    b = client.post("/api/auth/technician", json={"full_name": "Sam Two", "email": "sam@two.example"}).json()
    assert a["username"] == "sam" and b["username"] == "sam2"


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
