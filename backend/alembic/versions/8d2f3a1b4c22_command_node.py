"""command node (multi-server labs)

Revision ID: 8d2f3a1b4c22
Revises: 7c1e2f0a9b11
"""
from alembic import op
import sqlalchemy as sa

revision = "8d2f3a1b4c22"
down_revision = "7c1e2f0a9b11"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("commands", sa.Column("node", sa.String(32), nullable=False, server_default=""))


def downgrade() -> None:
    op.drop_column("commands", "node")
