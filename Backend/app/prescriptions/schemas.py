from pydantic import BaseModel, ConfigDict
from typing import List, Optional

def to_camel(string: str) -> str:
    parts = string.split('_')
    return parts[0] + ''.join(word.capitalize() for word in parts[1:])

class CamelModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True
    )

class PrescriptionItemBase(CamelModel):
    medicine_id: str
    quantity: int
    dosage: str

class PrescriptionItemCreate(PrescriptionItemBase):
    pass

class PrescriptionItemResponse(PrescriptionItemBase):
    pass

class PrescriptionBase(CamelModel):
    customer_id: str
    doctor_name: str
    doctor_license: str
    issued_at: str
    status: str
    image_url: Optional[str] = None
    notes: Optional[str] = None
    refills_remaining: int

class PrescriptionCreate(PrescriptionBase):
    id: str
    items: List[PrescriptionItemCreate]

class PrescriptionResponse(PrescriptionBase):
    id: str
    items: List[PrescriptionItemResponse]
