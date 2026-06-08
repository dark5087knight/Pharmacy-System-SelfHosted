from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import text
from typing import List, Optional
from datetime import datetime, date, timezone
import uuid

from app.shared.database import get_db
from app.shared.utils import to_uuid
from app.shared.responses import success_response
from app.dependencies import get_current_user
from app.models import Staff, Medicine, MedicineCategory, Branch
from app.inventory.schemas import MedicineCreate, MedicineResponse, MedicineBase

router = APIRouter(tags=["Inventory & Medicines"])

def format_medicine(m: Medicine) -> dict:
    """Format Medicine SQLAlchemy model into JSON response dict."""
    return {
        "id": str(m.id),
        "name": m.name,
        "genericName": m.generic_name,
        "brand": m.brand,
        "category": m.category.name if m.category else "Analgesic",
        "barcode": m.barcode,
        "sku": m.sku,
        "batchNumber": m.batch_number,
        "manufactureDate": str(m.manufacture_date) if m.manufacture_date else "",
        "expiryDate": str(m.expiry_date) if m.expiry_date else "",
        "quantity": m.quantity,
        "unit": m.unit,
        "purchasePrice": float(m.purchase_price),
        "sellingPrice": float(m.selling_price),
        "discount": float(m.discount),
        "taxRate": float(m.tax_rate),
        "lowStockThreshold": m.low_stock_threshold,
        "location": {
            "rack": m.rack or "",
            "shelf": m.shelf or "",
            "warehouse": m.warehouse or ""
        },
        "status": m.status,
        "controlled": m.controlled,
        "prescriptionRequired": m.prescription_required,
        "isPinned": m.is_pinned,
        "supplierId": str(m.supplier_id) if m.supplier_id else "",
        "description": m.description or "",
        "sideEffects": m.side_effects or [],
        "interactions": m.interactions or [],
        "dosage": m.dosage or "",
        "storage": m.storage or ""
    }

@router.get("/medicines", response_model=List[MedicineResponse])
async def read_medicines(
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    stmt = select(Medicine).filter(Medicine.deleted_at == None).options(selectinload(Medicine.category))
    result = await db.execute(stmt)
    medicines = result.scalars().all()
    return [format_medicine(m) for m in medicines]


@router.get("/medicines/search", response_model=List[MedicineResponse])
async def search_medicines(
    q: str, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    stmt = select(Medicine).filter(
        Medicine.deleted_at == None,
        (Medicine.name.ilike(f"%{q}%")) | (Medicine.generic_name.ilike(f"%{q}%"))
    ).options(selectinload(Medicine.category))
    result = await db.execute(stmt)
    medicines = result.scalars().all()
    return [format_medicine(m) for m in medicines]


@router.get("/medicines/{id}", response_model=MedicineResponse)
async def read_medicine(
    id: str, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    med_uuid = to_uuid(id, "medicine")
    stmt = select(Medicine).filter(Medicine.id == med_uuid, Medicine.deleted_at == None).options(selectinload(Medicine.category))
    result = await db.execute(stmt)
    m = result.scalars().first()
    if not m:
        raise HTTPException(status_code=404, detail="Medication not found")
    return format_medicine(m)


@router.post("/medicines", response_model=MedicineResponse)
async def create_medicine(
    m: MedicineCreate, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    if not m.expiry_date or not m.expiry_date.strip():
        raise HTTPException(status_code=400, detail="Expiry date is required.")
        
    med_uuid = to_uuid(m.id, "medicine")
    
    # Check if barcode or SKU already registered for this tenant
    check_stmt = select(Medicine).filter(
        (Medicine.sku == m.sku) | (Medicine.barcode == m.barcode)
    )
    check_res = await db.execute(check_stmt)
    if check_res.scalars().first():
        raise HTTPException(status_code=400, detail="SKU or Barcode already registered.")

    # Find or create category for this tenant
    cat_stmt = select(MedicineCategory).filter(
        MedicineCategory.name == m.category
    )
    cat_res = await db.execute(cat_stmt)
    db_cat = cat_res.scalars().first()
    
    if not db_cat:
        db_cat = MedicineCategory(
            id=uuid.uuid4(),
            name=m.category,
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc)
        )
        db.add(db_cat)
        await db.flush() # ensure category ID is generated

    # Fetch default branch
    branch_stmt = select(Branch)
    branch_res = await db.execute(branch_stmt)
    default_branch = branch_res.scalars().first()
    branch_id = default_branch.id if default_branch else None

    db_med = Medicine(
        id=med_uuid,
        branch_id=branch_id,
        supplier_id=to_uuid(m.supplier_id, "supplier") if m.supplier_id else None,
        category_id=db_cat.id,
        name=m.name,
        generic_name=m.generic_name,
        brand=m.brand,
        barcode=m.barcode,
        sku=m.sku,
        batch_number=m.batch_number,
        manufacture_date=date.fromisoformat(m.manufacture_date[:10]) if m.manufacture_date else None,
        expiry_date=date.fromisoformat(m.expiry_date[:10]) if m.expiry_date else None,
        quantity=m.quantity,
        unit=m.unit,
        purchase_price=m.purchase_price,
        selling_price=m.selling_price,
        discount=m.discount,
        tax_rate=m.tax_rate,
        low_stock_threshold=m.low_stock_threshold if m.low_stock_threshold is not None else 10,
        rack=m.location.rack,
        shelf=m.location.shelf,
        warehouse=m.location.warehouse,
        status=m.status,
        controlled=m.controlled,
        prescription_required=m.prescription_required,
        is_pinned=m.is_pinned if m.is_pinned is not None else False,
        description=m.description,
        side_effects=m.side_effects,
        interactions=m.interactions,
        dosage=m.dosage,
        storage=m.storage,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
        created_by=current_user.id,
        updated_by=current_user.id
    )
    db.add(db_med)
    await db.commit()
    
    # Reload with category joined
    stmt = select(Medicine).filter(Medicine.id == db_med.id).options(selectinload(Medicine.category))
    res = await db.execute(stmt)
    return format_medicine(res.scalars().first())


@router.put("/medicines/{id}", response_model=MedicineResponse)
async def update_medicine(
    id: str, 
    m: MedicineBase, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    if not m.expiry_date or not m.expiry_date.strip():
        raise HTTPException(status_code=400, detail="Expiry date is required.")
        
    med_uuid = to_uuid(id, "medicine")
    
    stmt = select(Medicine).filter(Medicine.id == med_uuid, Medicine.deleted_at == None).options(selectinload(Medicine.category))
    result = await db.execute(stmt)
    db_med = result.scalars().first()
    
    if not db_med:
        raise HTTPException(status_code=404, detail="Medication not found")

    # Find or create category
    cat_stmt = select(MedicineCategory).filter(
        MedicineCategory.name == m.category
    )
    cat_res = await db.execute(cat_stmt)
    db_cat = cat_res.scalars().first()
    
    if not db_cat:
        db_cat = MedicineCategory(
            id=uuid.uuid4(),
            name=m.category,
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc)
        )
        db.add(db_cat)
        await db.flush()

    db_med.name = m.name
    db_med.generic_name = m.generic_name
    db_med.brand = m.brand
    db_med.category_id = db_cat.id
    db_med.barcode = m.barcode
    db_med.sku = m.sku
    db_med.batch_number = m.batch_number
    db_med.manufacture_date = date.fromisoformat(m.manufacture_date[:10]) if m.manufacture_date else None
    db_med.expiry_date = date.fromisoformat(m.expiry_date[:10]) if m.expiry_date else None
    db_med.quantity = m.quantity
    db_med.unit = m.unit
    db_med.purchase_price = m.purchase_price
    db_med.selling_price = m.selling_price
    db_med.discount = m.discount
    db_med.tax_rate = m.tax_rate
    db_med.low_stock_threshold = m.low_stock_threshold if m.low_stock_threshold is not None else 10
    db_med.rack = m.location.rack
    db_med.shelf = m.location.shelf
    db_med.warehouse = m.location.warehouse
    db_med.status = m.status
    db_med.controlled = m.controlled
    db_med.prescription_required = m.prescription_required
    db_med.is_pinned = m.is_pinned if m.is_pinned is not None else False
    db_med.supplier_id = to_uuid(m.supplier_id, "supplier") if m.supplier_id else None
    db_med.description = m.description
    db_med.side_effects = m.side_effects
    db_med.interactions = m.interactions
    db_med.dosage = m.dosage
    db_med.storage = m.storage
    db_med.updated_at = datetime.now(timezone.utc)
    db_med.updated_by = current_user.id

    db.add(db_med)
    await db.commit()
    
    # Reload with category joined
    stmt = select(Medicine).filter(Medicine.id == db_med.id).options(selectinload(Medicine.category))
    res = await db.execute(stmt)
    return format_medicine(res.scalars().first())


@router.delete("/medicines/{id}")
async def delete_medicine(
    id: str, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    med_uuid = to_uuid(id, "medicine")
    stmt = select(Medicine).filter(Medicine.id == med_uuid, Medicine.deleted_at == None)
    result = await db.execute(stmt)
    db_med = result.scalars().first()
    
    if not db_med:
        raise HTTPException(status_code=404, detail="Medication not found")
        
    db_med.deleted_at = datetime.now(timezone.utc)
    db.add(db_med)
    await db.commit()
    return {"detail": "Medication deleted successfully"}
