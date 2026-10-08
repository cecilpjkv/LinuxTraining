from fastapi import Cookie, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .db import get_db
from .models import User
from .security import COOKIE, read_token


def current_user(db: Session = Depends(get_db), token: str | None = Cookie(default=None, alias=COOKIE)) -> User:
    uid = read_token(token) if token else None
    user = db.get(User, uid) if uid else None
    if user is None or not user.active:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "not logged in")
    return user


def require_admin(user: User = Depends(current_user)) -> User:
    if user.role != "admin":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "administrators only")
    return user
