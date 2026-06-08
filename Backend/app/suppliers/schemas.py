from pydantic import BaseModel, ConfigDict
from typing import Optional

def to_camel(string: str) -> str:
    parts = string.split('_')
    return parts[0] + ''.join(word.capitalize() for word in parts[1:])

class CamelModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True
    )

class SupplierBase(CamelModel):
    name: str
    company: str
    email: Optional[str] = None
    phone: str
    address: str
    rating: float
    outstanding_balance: float
    total_purchased: float
    status: str
    notes: Optional[str] = None

class SupplierCreate(SupplierBase):
    id: str

class SupplierResponse(SupplierBase):
    id: str
