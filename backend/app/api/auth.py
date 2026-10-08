from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..deps import current_user
from ..models import User
from ..schemas import LoginIn, RegisterIn, UserOut
from ..security import COOKIE, check_password_policy, hash_password, make_token, verify_password

router = APIRouter(prefix="/api/auth", tags=["auth"])

# verified against when the user does not exist, so both cases take the same time
_DUMMY = hash_password("not-a-real-password")


def _set_cookie(resp: Response, user: User) -> None:
    resp.set_cookie(COOKIE, make_token(user.id, user.role), httponly=True, samesite="strict", secure=settings.cookie_secure,
                    max_age=settings.token_hours * 3600, path="/")


@router.post("/login", response_model=UserOut)
def login(body: LoginIn, resp: Response, db: Session = Depends(get_db)) -> User:
    name = body.username.strip()
    user = db.scalar(select(User).where(or_(User.username == name, User.email == name.lower())))
    ok = verify_password(body.password, user.password_hash if user else _DUMMY)
    if not user or not ok or not user.active:
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
