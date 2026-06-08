from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List
from datetime import datetime, date, timezone
import uuid

from app.shared.database import get_db
from app.shared.utils import to_uuid
from app.shared.responses import success_response
from app.dependencies import get_current_user
from app.models import Staff, Customer
from app.customers.schemas import CustomerCreate, CustomerResponse, CustomerBase

router = APIRouter(tags=["Customers"])

def format_customer(c: Customer) -> dict:
    return {
        "id": str(c.id),
        "name": c.name,
        "phone": c.phone,
        "email": c.email or "",
        "dateOfBirth": str(c.date_of_birth) if c.date_of_birth else "",
        "loyaltyPoints": c.loyalty_points,
        "membershipLevel": c.membership_level,
        "allergies": c.allergies or [],
        "insurance": {
            "provider": c.insurance_provider or "",
            "policy": c.insurance_policy or ""
        } if (c.insurance_provider or c.insurance_policy) else None,
        "balance": float(c.balance),
        "totalSpent": float(c.total_spent),
        "visits": c.visits,
        "notes": c.notes or ""
    }

@router.get("/customers", response_model=List[CustomerResponse])
async def read_customers(
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    stmt = select(Customer).filter(Customer.deleted_at == None)
    result = await db.execute(stmt)
    customers = result.scalars().all()
    return [format_customer(c) for c in customers]


@router.get("/customers/{id}", response_model=CustomerResponse)
async def read_customer(
    id: str, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    cust_uuid = to_uuid(id, "customer")
    stmt = select(Customer).filter(Customer.id == cust_uuid, Customer.deleted_at == None)
    result = await db.execute(stmt)
    c = result.scalars().first()
    if not c:
        raise HTTPException(status_code=404, detail="Customer not found")
    return format_customer(c)


@router.post("/customers", response_model=CustomerResponse)
async def create_customer(
    c: CustomerCreate, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    cust_uuid = to_uuid(c.id, "customer")
    
    # Check if phone is already registered
    check_stmt = select(Customer).filter(
        Customer.phone == c.phone
    )
    check_res = await db.execute(check_stmt)
    if check_res.scalars().first():
        raise HTTPException(status_code=400, detail="Customer with this phone number already exists.")

    db_cust = Customer(
        id=cust_uuid,
        name=c.name,
        phone=c.phone,
        email=c.email,
        date_of_birth=date.fromisoformat(c.date_of_birth[:10]) if c.date_of_birth else None,
        loyalty_points=c.loyalty_points,
        membership_level=c.membership_level,
        allergies=c.allergies,
        insurance_provider=c.insurance.provider if c.insurance else None,
        insurance_policy=c.insurance.policy if c.insurance else None,
        balance=c.balance,
        total_spent=c.total_spent,
        visits=c.visits,
        notes=c.notes,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
        created_by=current_user.id
    )
    db.add(db_cust)
    await db.commit()
    await db.refresh(db_cust)
    return format_customer(db_cust)


@router.put("/customers/{id}", response_model=CustomerResponse)
async def update_customer(
    id: str, 
    c: CustomerBase, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    cust_uuid = to_uuid(id, "customer")
    stmt = select(Customer).filter(Customer.id == cust_uuid)
    result = await db.execute(stmt)
    db_cust = result.scalars().first()
    
    if not db_cust:
        raise HTTPException(status_code=404, detail="Customer not found")
        
    db_cust.name = c.name
    db_cust.phone = c.phone
    db_cust.email = c.email
    db_cust.date_of_birth = date.fromisoformat(c.date_of_birth[:10]) if c.date_of_birth else None
    db_cust.loyalty_points = c.loyalty_points
    db_cust.membership_level = c.membership_level
    db_cust.allergies = c.allergies
    db_cust.insurance_provider = c.insurance.provider if c.insurance else None
    db_cust.insurance_policy = c.insurance.policy if c.insurance else None
    db_cust.balance = c.balance
    db_cust.total_spent = c.total_spent
    db_cust.visits = c.visits
    db_cust.notes = c.notes
    db_cust.updated_at = datetime.now(timezone.utc)
    
    db.add(db_cust)
    await db.commit()
    await db.refresh(db_cust)
    return format_customer(db_cust)


@router.delete("/customers/{id}")
async def delete_customer(
    id: str, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    cust_uuid = to_uuid(id, "customer")
    stmt = select(Customer).filter(Customer.id == cust_uuid, Customer.deleted_at == None)
    result = await db.execute(stmt)
    db_cust = result.scalars().first()
    
    if not db_cust:
        raise HTTPException(status_code=404, detail="Customer not found")
        
    db_cust.deleted_at = datetime.now(timezone.utc)
    db.add(db_cust)
    await db.commit()
    return {"detail": "Customer deleted successfully"}
