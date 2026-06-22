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
    barcode: Optional[str] = None
    sku: Optional[str] = None
    batch_number: Optional[str] = None
    manufacture_date: Optional[str] = None
    expiry_date: Optional[str] = None
    quantity: int
    unit: Optional[str] = None
    purchase_price: float
    selling_price: float
    discount: float
    tax_rate: float
    low_stock_threshold: Optional[int] = 10
    location: LocationSchema
    status: Optional[str] = None
    controlled: bool
    prescription_required: bool
    is_pinned: Optional[bool] = False
    supplier_id: Optional[str] = None
    description: Optional[str] = None
    side_effects: Optional[List[str]] = []
    interactions: Optional[List[str]] = []
    dosage: Optional[str] = None
    storage: Optional[str] = None
    image_url: Optional[str] = None
    company: Optional[str] = None
    indication: Optional[List[str]] = []
    dose: Optional[str] = None
    small_unit: Optional[str] = None
    equivalency: Optional[int] = None

class MedicineCreate(MedicineBase):
    id: str

class MedicineResponse(MedicineBase):
    id: str
