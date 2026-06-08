"""add is_pinned to medicine

Revision ID: 002_add_is_pinned_to_medicine
Revises: 001_initial_schema
Create Date: 2026-05-23

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '002_add_is_pinned_to_medicine'
down_revision = '001_initial_schema'
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.add_column('medicines', sa.Column('is_pinned', sa.Boolean(), nullable=False, server_default=sa.text('false')))

def downgrade() -> None:
    op.drop_column('medicines', 'is_pinned')
