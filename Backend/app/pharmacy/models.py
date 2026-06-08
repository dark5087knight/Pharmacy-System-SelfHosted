from sqlalchemy import Column, String, Boolean
from sqlalchemy.dialects.postgresql import UUID, JSONB
import uuid
from app.shared.database import Base
from app.shared.base_model import TimeStampedMixin

class PharmacySettings(Base, TimeStampedMixin):
    __tablename__ = "pharmacy_settings"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False, default="My Pharmacy")
    phone = Column(String(50))
    address = Column(String)
    country = Column(String(2), nullable=False, default="IQ")
    timezone = Column(String(100), nullable=False, default="Asia/Baghdad")
    locale = Column(String(20), nullable=False, default="en")
    currency = Column(String(3), nullable=False, default="IQD")
    logo_url = Column(String)
    settings = Column(JSONB, nullable=False, default=dict)


class Branch(Base, TimeStampedMixin):
    __tablename__ = "branches"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    address = Column(String)
    phone = Column(String(50))
    is_main = Column(Boolean, nullable=False, default=False)
    status = Column(String(20), nullable=False, default="active")
