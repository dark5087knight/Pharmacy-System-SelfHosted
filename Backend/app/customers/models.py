from sqlalchemy import Column, String, Integer, Numeric, ForeignKey, Date
from sqlalchemy.dialects.postgresql import UUID, JSONB
import uuid
from app.shared.database import Base
from app.shared.base_model import TimeStampedMixin, SoftDeleteMixin

class Customer(Base, TimeStampedMixin, SoftDeleteMixin):
    __tablename__ = "customers"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    phone = Column(String(50), nullable=False, unique=True)
    email = Column(String(255))
    date_of_birth = Column(Date)
    gender = Column(String(1))
    loyalty_points = Column(Integer, nullable=False, default=0)
    membership_level = Column(String(30), nullable=False, default="standard")
    allergies = Column(JSONB, nullable=False, default=list)
    insurance_provider = Column(String(255))
    insurance_policy = Column(String(255))
    balance = Column(Numeric(12, 2), nullable=False, default=0.00)
    total_spent = Column(Numeric(14, 2), nullable=False, default=0.00)
    visits = Column(Integer, nullable=False, default=0)
    notes = Column(String)
    created_by = Column(UUID(as_uuid=True), ForeignKey("staff.id"))
