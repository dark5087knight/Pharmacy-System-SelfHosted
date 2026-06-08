from sqlalchemy import Column, String, Integer, Numeric, Boolean, ForeignKey, DateTime, Date
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
import uuid
from datetime import datetime, timezone
from app.shared.database import Base
from app.shared.base_model import TimeStampedMixin, SoftDeleteMixin

class MedicineCategory(Base, TimeStampedMixin):
    __tablename__ = "medicine_categories"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False, unique=True)
    description = Column(String)


class Medicine(Base, TimeStampedMixin, SoftDeleteMixin):
    __tablename__ = "medicines"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    branch_id = Column(UUID(as_uuid=True), ForeignKey("branches.id"))
    supplier_id = Column(UUID(as_uuid=True), ForeignKey("suppliers.id"))
    category_id = Column(UUID(as_uuid=True), ForeignKey("medicine_categories.id"))
    name = Column(String(255), nullable=False)
    generic_name = Column(String(255), nullable=False)
    brand = Column(String(255), nullable=False)
    barcode = Column(String(100), unique=True)
    sku = Column(String(100), unique=True)
    batch_number = Column(String(100))
    manufacture_date = Column(Date)
    expiry_date = Column(Date, nullable=False)
    quantity = Column(Integer, nullable=False, default=0)
    unit = Column(String(30), nullable=False, default="tablet")
    purchase_price = Column(Numeric(12, 4), nullable=False, default=0.0000)
    selling_price = Column(Numeric(12, 4), nullable=False, default=0.0000)
    discount = Column(Numeric(5, 2), nullable=False, default=0.00)
    tax_rate = Column(Numeric(5, 2), nullable=False, default=0.00)
    low_stock_threshold = Column(Integer, nullable=False, default=10)
    rack = Column(String(50))
    shelf = Column(String(50))
    warehouse = Column(String(100))
    status = Column(String(20), nullable=False, default="active")
    controlled = Column(Boolean, nullable=False, default=False)
    prescription_required = Column(Boolean, nullable=False, default=False)
    is_pinned = Column(Boolean, nullable=False, default=False)
    description = Column(String)
    side_effects = Column(JSONB, nullable=False, default=list)
    interactions = Column(JSONB, nullable=False, default=list)
    dosage = Column(String(255))
    storage = Column(String(255))
    image_url = Column(String)
    created_by = Column(UUID(as_uuid=True), ForeignKey("staff.id"))
    updated_by = Column(UUID(as_uuid=True), ForeignKey("staff.id"))

    category = relationship("MedicineCategory")


class StockMovement(Base):
    __tablename__ = "stock_movements"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    medicine_id = Column(UUID(as_uuid=True), ForeignKey("medicines.id"), nullable=False)
    movement_type = Column(String(30), nullable=False)
    quantity_before = Column(Integer, nullable=False)
    quantity_change = Column(Integer, nullable=False)
    quantity_after = Column(Integer, nullable=False)
    reference_id = Column(UUID(as_uuid=True))
    reference_type = Column(String(50))
    notes = Column(String)
    performed_by = Column(UUID(as_uuid=True), ForeignKey("staff.id"))
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
