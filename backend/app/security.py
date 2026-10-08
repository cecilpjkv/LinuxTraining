"""Passwords (scrypt from the standard library) and session tokens (JWT in an HttpOnly cookie)."""
import base64
import hashlib
import hmac
import os
from datetime import datetime, timedelta, timezone

import jwt

from .config import settings

_N, _R, _P = 2**14, 8, 1
COOKIE = "lt_session"


def hash_password(password: str) -> str:
    salt = os.urandom(16)
    dk = hashlib.scrypt(password.encode(), salt=salt, n=_N, r=_R, p=_P, dklen=32)
    return f"scrypt${_N}${_R}${_P}${base64.b64encode(salt).decode()}${base64.b64encode(dk).decode()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        algo, n, r, p, salt, dk = stored.split("$")
        if algo != "scrypt":
            return False
        got = hashlib.scrypt(password.encode(), salt=base64.b64decode(salt), n=int(n), r=int(r), p=int(p), dklen=32)
        return hmac.compare_digest(got, base64.b64decode(dk))
    except (ValueError, TypeError):
        return False


def make_token(user_id: int, role: str) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode({"sub": str(user_id), "role": role, "iat": now, "exp": now + timedelta(hours=settings.token_hours)},
                      settings.secret_key, algorithm="HS256")


def read_token(token: str) -> int | None:
    try:
        data = jwt.decode(token, settings.secret_key, algorithms=["HS256"])
        return int(data["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        return None


def check_password_policy(password: str) -> str | None:
    if len(password) < 10:
        return "password must be at least 10 characters"
    if len(password) > 256:
        return "password is too long"
    return None
