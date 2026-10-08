import threading
import time
from collections import defaultdict, deque
from datetime import datetime, timezone

from fastapi import APIRouter, Cookie, Depends, HTTPException, Request, Response, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..deps import current_user
from ..models import User
from ..schemas import LoginIn, RegisterIn, UserOut
from ..security import COOKIE, check_password_policy, hash_password, make_token, read_token, verify_password

router = APIRouter(prefix="/api/auth", tags=["auth"])

# verified against when the user does not exist, so both cases take the same time
_DUMMY = hash_password("not-a-real-password")


def _set_cookie(resp: Response, user: User) -> None:
    resp.set_cookie(COOKIE, make_token(user.id, user.role), httponly=True, samesite="strict", secure=settings.cookie_secure,
                    max_age=settings.token_hours * 3600, path="/")


# brute-force brake: 10 failures per username or per client address within 15 minutes -> 429 until they age out
_FAILS: dict[str, deque] = defaultdict(deque)
_FAILS_LOCK = threading.Lock()
WINDOW, LIMIT = 15 * 60, 10


def _throttled(keys: list[str]) -> bool:
    cut = time.monotonic() - WINDOW
    with _FAILS_LOCK:
        for k in keys:
            q = _FAILS[k]
            while q and q[0] < cut:
                q.popleft()
            if len(q) >= LIMIT:
                return True
    return False


def _failed(keys: list[str]) -> None:
    with _FAILS_LOCK:
        for k in keys:
            _FAILS[k].append(time.monotonic())
        if len(_FAILS) > 50000:
            _FAILS.clear()


@router.post("/login", response_model=UserOut)
def login(body: LoginIn, req: Request, resp: Response, db: Session = Depends(get_db)) -> User:
    name = body.username.strip()
    keys = [f"u:{name.lower()}", f"ip:{req.client.host if req.client else '-'}"]
    if _throttled(keys):
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "too many failed logins; wait 15 minutes")
    user = db.scalar(select(User).where(or_(User.username == name, User.email == name.lower())))
    ok = verify_password(body.password, user.password_hash if user else _DUMMY)
    if not user or not ok or not user.active:
        _failed(keys)
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "wrong username or password")
    user.last_login_at = datetime.now(timezone.utc)
    db.commit()
    _set_cookie(resp, user)
    return user


@router.post("/register", response_model=UserOut, status_code=201)
def register(body: RegisterIn, resp: Response, db: Session = Depends(get_db)) -> User:
    if not settings.allow_registration:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "registration is disabled; ask an administrator")
    if msg := check_password_policy(body.password):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, msg)
    email = body.email.lower() if body.email else None
    clash = db.scalar(select(User).where(or_(User.username == body.username, User.email == email) if email else User.username == body.username))
    if clash:
        raise HTTPException(status.HTTP_409_CONFLICT, "username or e-mail already registered")
    user = User(username=body.username, email=email, full_name=body.full_name, password_hash=hash_password(body.password),
                role="technician")  # self-registration never creates an administrator
    db.add(user)
    db.commit()
    _set_cookie(resp, user)
    return user


@router.post("/logout", status_code=204)
def logout(resp: Response) -> None:
    resp.delete_cookie(COOKIE, path="/")


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(current_user)) -> User:
    return user


@router.get("/session")
def session(db: Session = Depends(get_db), token: str | None = Cookie(default=None, alias=COOKIE)) -> dict:
    """Who is logged in, without an error status for "nobody" (the app asks before the login page)."""
    uid = read_token(token) if token else None
    user = db.get(User, uid) if uid else None
    return {"user": UserOut.model_validate(user).model_dump(mode="json") if user and user.active else None}
