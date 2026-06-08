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

class SaleItemBase(CamelModel):
    medicine_id: str
    name: str
    quantity: int
    unit_price: float
    discount: float
    tax_rate: float

class SaleItemCreate(SaleItemBase):
    pass

class SaleItemResponse(SaleItemBase):
    pass

class SaleBase(CamelModel):
    invoice_number: str
    customer_id: Optional[str] = None
    cashier_id: str
    subtotal: float
    discount: float
    tax: float
    total: float
    payment_method: str
    status: str
    created_at: str

class SaleCreate(SaleBase):
    id: str
    items: List[SaleItemCreate]

class SaleResponse(SaleBase):
    id: str
    items: List[SaleItemResponse]

class SaleReturnCreate(CamelModel):
    medicine_id: str
    customer_name: str
    returned_quantity: int
