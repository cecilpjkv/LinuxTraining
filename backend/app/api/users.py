from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import require_admin
from ..models import User
from ..schemas import UserOut, UserUpdate

router = APIRouter(prefix="/api/admin/users", tags=["admin"], dependencies=[Depends(require_admin)])


@router.get("", response_model=list[UserOut])
def list_users(db: Session = Depends(get_db)) -> list[User]:
    return list(db.scalars(select(User).order_by(User.username)))


@router.patch("/{user_id}", response_model=UserOut)
def update_user(user_id: int, body: UserUpdate, db: Session = Depends(get_db), admin: User = Depends(require_admin)) -> User:
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(404, "no such user")
    if user.id == admin.id and (body.role == "technician" or body.active is False):
        raise HTTPException(400, "you cannot demote or disable your own account")
    for k, v in body.model_dump(exclude_none=True).items():
        setattr(user, k, v)
    db.commit()
    return user
