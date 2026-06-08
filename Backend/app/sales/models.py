from sqlalchemy import Column, String, Integer, Numeric, ForeignKey, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
from datetime import datetime, timezone
from app.shared.database import Base
from app.shared.base_model import TimeStampedMixin

class Sale(Base, TimeStampedMixin):
    __tablename__ = "sales"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    branch_id = Column(UUID(as_uuid=True), ForeignKey("branches.id"))
    invoice_number = Column(String(50), nullable=False, unique=True)
    customer_id = Column(UUID(as_uuid=True), ForeignKey("customers.id"))
    cashier_id = Column(UUID(as_uuid=True), ForeignKey("staff.id"), nullable=False)
    prescription_id = Column(UUID(as_uuid=True), ForeignKey("prescriptions.id"))
    subtotal = Column(Numeric(14, 2), nullable=False, default=0.00)
    discount = Column(Numeric(14, 2), nullable=False, default=0.00)
    tax = Column(Numeric(14, 2), nullable=False, default=0.00)
    total = Column(Numeric(14, 2), nullable=False, default=0.00)
    payment_method = Column(String(30), nullable=False)
    status = Column(String(30), nullable=False, default="completed")
    notes = Column(String)

    items = relationship("SaleItem", back_populates="sale", cascade="all, delete-orphan")


class SaleItem(Base):
    __tablename__ = "sale_items"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    sale_id = Column(UUID(as_uuid=True), ForeignKey("sales.id", ondelete="CASCADE"), nullable=False)
    medicine_id = Column(UUID(as_uuid=True), ForeignKey("medicines.id"), nullable=False)
    name = Column(String(255), nullable=False)
    quantity = Column(Integer, nullable=False)
    unit_price = Column(Numeric(12, 4), nullable=False)
    discount = Column(Numeric(5, 2), nullable=False, default=0.00)
    tax_rate = Column(Numeric(5, 2), nullable=False, default=0.00)
    line_total = Column(Numeric(14, 2), nullable=False)

    sale = relationship("Sale", back_populates="items")


class Payment(Base):
    __tablename__ = "payments"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    sale_id = Column(UUID(as_uuid=True), ForeignKey("sales.id", ondelete="CASCADE"), nullable=False)
    amount = Column(Numeric(14, 2), nullable=False)
    method = Column(String(30), nullable=False)
    status = Column(String(20), nullable=False, default="completed")
    reference = Column(String(255))
    paid_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    created_by = Column(UUID(as_uuid=True), ForeignKey("staff.id"))
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
