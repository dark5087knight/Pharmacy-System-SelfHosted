"""add medicine fields

Revision ID: 003_add_medicine_fields
Revises: 002_add_is_pinned_to_medicine
Create Date: 2026-06-22

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

# revision identifiers, used by Alembic.
revision = '003_add_medicine_fields'
down_revision = '002_add_is_pinned_to_medicine'
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.add_column('medicines', sa.Column('company', sa.String(length=255), nullable=True))
    op.add_column('medicines', sa.Column('indication', JSONB(astext_type=sa.Text()), nullable=False, server_default='[]'))
    op.add_column('medicines', sa.Column('dose', sa.String(length=255), nullable=True))
    op.add_column('medicines', sa.Column('small_unit', sa.String(length=100), nullable=True))
    op.add_column('medicines', sa.Column('equivalency', sa.Integer(), nullable=True))

def downgrade() -> None:
    op.drop_column('medicines', 'equivalency')
    op.drop_column('medicines', 'small_unit')
    op.drop_column('medicines', 'dose')
    op.drop_column('medicines', 'indication')
    op.drop_column('medicines', 'company')
