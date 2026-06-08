from sqlalchemy import Column, String, Integer, ForeignKey, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
from app.shared.database import Base
from app.shared.base_model import TimeStampedMixin

class Prescription(Base, TimeStampedMixin):
    __tablename__ = "prescriptions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    customer_id = Column(UUID(as_uuid=True), ForeignKey("customers.id"), nullable=False)
    doctor_name = Column(String(255), nullable=False)
    doctor_license = Column(String(100))
    issued_at = Column(DateTime(timezone=True), nullable=False)
    status = Column(String(30), nullable=False, default="pending")
    image_url = Column(String)
    notes = Column(String)
    refills_remaining = Column(Integer, nullable=False, default=0)
    verified_by = Column(UUID(as_uuid=True), ForeignKey("staff.id"))
    created_by = Column(UUID(as_uuid=True), ForeignKey("staff.id"))

    items = relationship("PrescriptionItem", back_populates="prescription", cascade="all, delete-orphan")


class PrescriptionItem(Base):
    __tablename__ = "prescription_items"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    prescription_id = Column(UUID(as_uuid=True), ForeignKey("prescriptions.id", ondelete="CASCADE"), nullable=False)
    medicine_id = Column(UUID(as_uuid=True), ForeignKey("medicines.id"), nullable=False)
    quantity = Column(Integer, nullable=False)
    dosage = Column(String(255), nullable=False)
    instructions = Column(String)

    prescription = relationship("Prescription", back_populates="items")
