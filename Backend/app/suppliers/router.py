from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List
from datetime import datetime, timezone
import uuid

from app.shared.database import get_db
from app.shared.utils import to_uuid
from app.shared.responses import success_response
from app.dependencies import get_current_user
from app.models import Staff, Supplier
from app.suppliers.schemas import SupplierCreate, SupplierResponse, SupplierBase

router = APIRouter(tags=["Suppliers"])

def format_supplier(s: Supplier) -> dict:
    return {
        "id": str(s.id),
        "name": s.name,
        "company": s.company,
        "email": s.email or "",
        "phone": s.phone or "",
        "address": s.address or "",
        "rating": float(s.rating),
        "outstandingBalance": float(s.outstanding_balance),
        "totalPurchased": float(s.total_purchased),
        "status": s.status,
        "notes": s.notes
    }

@router.get("/suppliers", response_model=List[SupplierResponse])
async def read_suppliers(
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    stmt = select(Supplier).filter(Supplier.deleted_at == None)
    result = await db.execute(stmt)
    suppliers = result.scalars().all()
    return [format_supplier(s) for s in suppliers]


@router.get("/suppliers/{id}", response_model=SupplierResponse)
async def read_supplier(
    id: str, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    sup_uuid = to_uuid(id, "supplier")
    stmt = select(Supplier).filter(Supplier.id == sup_uuid, Supplier.deleted_at == None)
    result = await db.execute(stmt)
    s = result.scalars().first()
    if not s:
        raise HTTPException(status_code=404, detail="Supplier not found")
    return format_supplier(s)


@router.post("/suppliers", response_model=SupplierResponse)
async def create_supplier(
    s: SupplierCreate, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    sup_uuid = to_uuid(s.id, "supplier")
    
    db_sup = Supplier(
        id=sup_uuid,
        name=s.name,
        company=s.company,
        email=s.email,
        phone=s.phone,
        address=s.address,
        rating=s.rating,
        outstanding_balance=s.outstanding_balance,
        total_purchased=s.total_purchased,
        status=s.status,
        notes=s.notes,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
        created_by=current_user.id
    )
    db.add(db_sup)
    await db.commit()
    await db.refresh(db_sup)
    return format_supplier(db_sup)


@router.put("/suppliers/{id}", response_model=SupplierResponse)
async def update_supplier(
    id: str, 
    s: SupplierBase, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    sup_uuid = to_uuid(id, "supplier")
    stmt = select(Supplier).filter(Supplier.id == sup_uuid, Supplier.deleted_at == None)
    result = await db.execute(stmt)
    db_sup = result.scalars().first()
    
    if not db_sup:
        raise HTTPException(status_code=404, detail="Supplier not found")
        
    for key, val in s.model_dump().items():
        setattr(db_sup, key, val)
    db_sup.updated_at = datetime.now(timezone.utc)
    
    db.add(db_sup)
    await db.commit()
    await db.refresh(db_sup)
    return format_supplier(db_sup)


@router.delete("/suppliers/{id}")
async def delete_supplier(
    id: str, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    sup_uuid = to_uuid(id, "supplier")
    stmt = select(Supplier).filter(Supplier.id == sup_uuid, Supplier.deleted_at == None)
    result = await db.execute(stmt)
    db_sup = result.scalars().first()
    
    if not db_sup:
        raise HTTPException(status_code=404, detail="Supplier not found")
        
    db_sup.deleted_at = datetime.now(timezone.utc)
    db.add(db_sup)
    await db.commit()
    return {"detail": "Supplier deleted successfully"}
