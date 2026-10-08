"""attempt last_seen_at (idle abandonment)

Revision ID: 7c1e2f0a9b11
Revises: 5a6b7a7995f1
"""
from alembic import op
import sqlalchemy as sa

revision = "7c1e2f0a9b11"
down_revision = "5a6b7a7995f1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("training_attempts", sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("training_attempts", "last_seen_at")
