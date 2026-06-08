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

class PurchaseOrderItemBase(CamelModel):
    medicine_id: str
    quantity: int
    unit_cost: float

class PurchaseOrderItemCreate(PurchaseOrderItemBase):
    pass

class PurchaseOrderItemResponse(PurchaseOrderItemBase):
    pass

class PurchaseOrderBase(CamelModel):
    po_number: str
    supplier_id: str
    status: str
    total: float
    created_at: str
    expected_at: Optional[str] = None
    received_at: Optional[str] = None

class PurchaseOrderCreate(PurchaseOrderBase):
    id: str
    items: List[PurchaseOrderItemCreate]

class PurchaseOrderResponse(PurchaseOrderBase):
    id: str
    items: List[PurchaseOrderItemResponse]
