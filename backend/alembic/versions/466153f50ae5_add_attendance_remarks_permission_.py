"""add attendance remarks permission fields and leave duration

Revision ID: 466153f50ae5
Revises: bc39e8d8892f
Create Date: 2026-03-17 15:00:19.072390

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '466153f50ae5'
down_revision: Union[str, Sequence[str], None] = 'bc39e8d8892f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'attendance',
        sa.Column('remarks', sa.String(), nullable=True)
    )

    op.add_column(
        'attendance',
        sa.Column('day_fraction', sa.Float(), nullable=False, server_default='0.0')
    )

    op.add_column(
        'attendance',
        sa.Column('used_permission', sa.Boolean(), nullable=False, server_default=sa.text('false'))
    )

    op.add_column(
        'leaves',
        sa.Column('permission_duration', sa.String(), nullable=True)
    )

    # optional: remove defaults after old rows are filled
    op.alter_column('attendance', 'day_fraction', server_default=None)
    op.alter_column('attendance', 'used_permission', server_default=None)

def downgrade() -> None:
    op.drop_column('leaves', 'permission_duration')
    op.drop_column('attendance', 'used_permission')
    op.drop_column('attendance', 'day_fraction')
    op.drop_column('attendance', 'remarks')
