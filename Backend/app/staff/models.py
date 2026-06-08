from sqlalchemy import Column, String, Integer, Boolean, ForeignKey, DateTime, Table
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
from datetime import datetime, timezone
from app.shared.database import Base
from app.shared.base_model import TimeStampedMixin, SoftDeleteMixin

# M:M Junction table for roles <-> permissions
role_permissions = Table(
    "role_permissions",
    Base.metadata,
    Column("role_id", UUID(as_uuid=True), ForeignKey("roles.id", ondelete="CASCADE"), primary_key=True),
    Column("permission_id", UUID(as_uuid=True), ForeignKey("permissions.id", ondelete="CASCADE"), primary_key=True),
)

class Permission(Base):
    __tablename__ = "permissions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code = Column(String(100), nullable=False, unique=True)
    description = Column(String)
    module = Column(String(50), nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))


class Role(Base, TimeStampedMixin):
    __tablename__ = "roles"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False, unique=True)
    description = Column(String)
    is_system = Column(Boolean, nullable=False, default=False)

    permissions = relationship("Permission", secondary=role_permissions)


class UserRole(Base):
    __tablename__ = "user_roles"

    staff_id = Column(UUID(as_uuid=True), ForeignKey("staff.id", ondelete="CASCADE"), primary_key=True)
    role_id = Column(UUID(as_uuid=True), ForeignKey("roles.id", ondelete="CASCADE"), primary_key=True)
    granted_by = Column(UUID(as_uuid=True), ForeignKey("staff.id"))
    granted_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))


class Staff(Base, TimeStampedMixin, SoftDeleteMixin):
    __tablename__ = "staff"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    username = Column(String(100), nullable=False, unique=True)
    email = Column(String(255), nullable=True)
    phone = Column(String(50))
    password_hash = Column(String)
    status = Column(String(30), nullable=False, default="active")
    shift = Column(String(20), nullable=False, default="morning")
    avatar_url = Column(String)
    joined_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    last_seen_at = Column(DateTime(timezone=True))

    roles = relationship(
        "Role",
        secondary="user_roles",
        primaryjoin="Staff.id == UserRole.staff_id",
        secondaryjoin="Role.id == UserRole.role_id",
        backref="staff_members"
    )
