from pydantic import BaseModel, ConfigDict
from typing import Optional, List

def to_camel(string: str) -> str:
    parts = string.split('_')
    return parts[0] + ''.join(word.capitalize() for word in parts[1:])

class CamelModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True
    )

class InsuranceSchema(CamelModel):
    provider: str
    policy: str

class CustomerBase(CamelModel):
    name: str
    phone: str
    email: Optional[str] = None
    date_of_birth: Optional[str] = None
    loyalty_points: int
    membership_level: str
    allergies: List[str]
    insurance: Optional[InsuranceSchema] = None
    balance: float
    total_spent: float
    visits: int
    notes: Optional[str] = None

class CustomerCreate(CustomerBase):
    id: str

class CustomerResponse(CustomerBase):
    id: str
