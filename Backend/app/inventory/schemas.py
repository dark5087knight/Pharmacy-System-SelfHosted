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

class LocationSchema(CamelModel):
    rack: str
    shelf: str
    warehouse: str

class MedicineBase(CamelModel):
    name: str
    generic_name: str
    brand: str
    category: str  # Category name (mapped to category_id on write)
    barcode: str
    sku: str
    batch_number: str
    manufacture_date: str
    expiry_date: str
    quantity: int
    unit: str
    purchase_price: float
    selling_price: float
    discount: float
    tax_rate: float
    low_stock_threshold: Optional[int] = 10
    location: LocationSchema
    status: str
    controlled: bool
    prescription_required: bool
    is_pinned: Optional[bool] = False
    supplier_id: str
    description: str
    side_effects: List[str]
    interactions: List[str]
    dosage: str
    storage: str
    image_url: Optional[str] = None

class MedicineCreate(MedicineBase):
    id: str

class MedicineResponse(MedicineBase):
    id: str
