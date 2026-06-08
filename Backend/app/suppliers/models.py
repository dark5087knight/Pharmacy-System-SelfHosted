from sqlalchemy import Column, String, Numeric, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
import uuid
from app.shared.database import Base
from app.shared.base_model import TimeStampedMixin, SoftDeleteMixin

class Supplier(Base, TimeStampedMixin, SoftDeleteMixin):
    __tablename__ = "suppliers"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    company = Column(String(255), nullable=False)
    email = Column(String(255))
    phone = Column(String(50))
    address = Column(String)
    rating = Column(Numeric(3, 2), nullable=False, default=0.00)
    outstanding_balance = Column(Numeric(14, 2), nullable=False, default=0.00)
    total_purchased = Column(Numeric(14, 2), nullable=False, default=0.00)
    status = Column(String(20), nullable=False, default="active")
    notes = Column(String)
    created_by = Column(UUID(as_uuid=True), ForeignKey("staff.id"))
