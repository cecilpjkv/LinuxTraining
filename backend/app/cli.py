"""Administration from the shell: python -m app.cli create-admin USERNAME [--email E]  (the password is read from
the terminal or LT_ADMIN_PASSWORD, never from the command line)."""
import argparse
import getpass
import os
import sys

from sqlalchemy import select

from .db import SessionLocal
from .models import User
from .security import check_password_policy, hash_password


def create_admin(username: str, email: str | None) -> int:
    password = os.environ.get("LT_ADMIN_PASSWORD") or getpass.getpass("Password: ")
    if msg := check_password_policy(password):
        print(msg, file=sys.stderr)
        return 1
    with SessionLocal() as db:
        user = db.scalar(select(User).where(User.username == username))
        if user:
            user.role, user.active, user.password_hash = "admin", True, hash_password(password)
            print(f"updated {username}: administrator, password reset")
        else:
            db.add(User(username=username, email=email.lower() if email else None, role="admin", password_hash=hash_password(password)))
            print(f"created administrator {username}")
        db.commit()
    return 0


def main() -> int:
    p = argparse.ArgumentParser(prog="python -m app.cli")
    sub = p.add_subparsers(dest="cmd", required=True)
    ca = sub.add_parser("create-admin")
    ca.add_argument("username")
    ca.add_argument("--email")
    a = p.parse_args()
    if a.cmd == "create-admin":
        return create_admin(a.username, a.email)
    return 2


if __name__ == "__main__":
    sys.exit(main())
