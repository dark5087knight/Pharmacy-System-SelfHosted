from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from typing import List
from datetime import datetime, timezone
import uuid

from app.shared.database import get_db
from app.shared.utils import to_uuid
from app.shared.responses import success_response
from app.dependencies import get_current_user, require_permission
from app.models import Staff, Sale, SaleItem, Medicine, StockMovement, Branch
from app.sales.schemas import SaleCreate, SaleResponse, SaleReturnCreate

router = APIRouter(tags=["Sales & POS"])

def format_sale(s: Sale) -> dict:
    items = [{
        "medicineId": str(it.medicine_id),
        "name": it.name,
        "quantity": it.quantity,
        "unitPrice": float(it.unit_price),
        "discount": float(it.discount),
        "taxRate": float(it.tax_rate)
    } for it in s.items]
    
    return {
        "id": str(s.id),
        "invoiceNumber": s.invoice_number,
        "customerId": str(s.customer_id) if s.customer_id else None,
        "cashierId": str(s.cashier_id),
        "subtotal": float(s.subtotal),
        "discount": float(s.discount),
        "tax": float(s.tax),
        "total": float(s.total),
        "paymentMethod": s.payment_method,
        "status": s.status,
        "createdAt": s.created_at.isoformat(),
        "items": items
    }

@router.get("/sales", response_model=List[SaleResponse])
async def read_sales(
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(require_permission("view_sales"))
):
    stmt = select(Sale).options(selectinload(Sale.items))
    result = await db.execute(stmt)
    sales = result.scalars().all()
    return [format_sale(s) for s in sales]


@router.post("/sales", response_model=SaleResponse)
async def create_sale(
    s: SaleCreate, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    sale_uuid = to_uuid(s.id, "sale")
    
    # Check if invoice number is already registered
    check_stmt = select(Sale).filter(
        Sale.invoice_number == s.invoice_number
    )
    check_res = await db.execute(check_stmt)
    if check_res.scalars().first():
        raise HTTPException(status_code=400, detail="Invoice number already exists.")

    # Fetch default branch
    branch_stmt = select(Branch)
    branch_res = await db.execute(branch_stmt)
    default_branch = branch_res.scalars().first()
    branch_id = default_branch.id if default_branch else None

    db_sale = Sale(
        id=sale_uuid,
        branch_id=branch_id,
        invoice_number=s.invoice_number,
        customer_id=to_uuid(s.customer_id, "customer") if s.customer_id else None,
        cashier_id=to_uuid(s.cashier_id, "staff") if s.cashier_id else current_user.id,
        prescription_id=None,
        subtotal=s.subtotal,
        discount=s.discount,
        tax=s.tax,
        total=s.total,
        payment_method=s.payment_method,
        status=s.status,
        created_at=datetime.fromisoformat(s.created_at.replace("Z", "+00:00")),
        updated_at=datetime.now(timezone.utc)
    )
    db.add(db_sale)
    await db.flush() # ensure Sale ID is available

    for item in s.items:
        med_uuid = to_uuid(item.medicine_id, "medicine")
        
        line_total = round((float(item.unit_price) * item.quantity) * (1 - float(item.discount)/100), 2)
        
        db_item = SaleItem(
            id=uuid.uuid4(),
            sale_id=db_sale.id,
            medicine_id=med_uuid,
            name=item.name,
            quantity=item.quantity,
            unit_price=item.unit_price,
            discount=item.discount,
            tax_rate=item.tax_rate,
            line_total=line_total
        )
        db.add(db_item)

        # Decrement stock and write stock movement
        med_stmt = select(Medicine).filter(Medicine.id == med_uuid)
        med_res = await db.execute(med_stmt)
        db_med = med_res.scalars().first()
        
        if db_med:
            if db_med.quantity < item.quantity:
                raise HTTPException(status_code=400, detail=f"Insufficient stock for {db_med.name}. Available: {db_med.quantity}, Requested: {item.quantity}")
            qty_before = db_med.quantity
            db_med.quantity = max(0, db_med.quantity - item.quantity)
            qty_after = db_med.quantity

            
            db_movement = StockMovement(
                id=uuid.uuid4(),
                medicine_id=med_uuid,
                movement_type="sale",
                quantity_before=qty_before,
                quantity_change=-item.quantity,
                quantity_after=qty_after,
                reference_id=db_sale.id,
                reference_type="sale",
                notes=f"Sale transaction {db_sale.invoice_number}",
                performed_by=current_user.id,
                created_at=datetime.now(timezone.utc)
            )
            db.add(db_movement)
            
    await db.commit()
    
    # Reload with items loaded
    reload_stmt = select(Sale).filter(Sale.id == db_sale.id).options(selectinload(Sale.items))
    reload_res = await db.execute(reload_stmt)
    return format_sale(reload_res.scalars().first())


@router.post("/sales/return")
async def process_return(
    ret: SaleReturnCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Staff = Depends(require_permission("manage_sales"))
):
    med_uuid = to_uuid(ret.medicine_id, "medicine")
    
    # 1. Fetch medicine
    med_stmt = select(Medicine).filter(Medicine.id == med_uuid)
    med_res = await db.execute(med_stmt)
    db_med = med_res.scalars().first()
    if not db_med:
        raise HTTPException(status_code=404, detail="Medicine not found")
        
    # 2. Update stock
    qty_before = db_med.quantity
    db_med.quantity += ret.returned_quantity
    qty_after = db_med.quantity
    
    # 3. Create negative sale / return transaction
    inv_num = f"RET-{str(uuid.uuid4().int)[:10]}"
    
    subtotal = float(db_med.selling_price) * ret.returned_quantity
    tax = round(subtotal * float(db_med.tax_rate) / 100, 2)
    discount = round(subtotal * float(db_med.discount) / 100, 2)
    total = subtotal - discount + tax
    
    db_sale = Sale(
        id=uuid.uuid4(),
        branch_id=db_med.branch_id,
        invoice_number=inv_num,
        customer_id=None,
        cashier_id=current_user.id,
        prescription_id=None,
        subtotal=-subtotal,
        discount=-discount,
        tax=-tax,
        total=-total,
        payment_method="cash",
        status="refunded",
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc)
    )
    db.add(db_sale)
    await db.flush()
    
    db_item = SaleItem(
        id=uuid.uuid4(),
        sale_id=db_sale.id,
        medicine_id=med_uuid,
        name=db_med.name,
        quantity=ret.returned_quantity,
        unit_price=float(db_med.selling_price),
        discount=float(db_med.discount),
        tax_rate=float(db_med.tax_rate),
        line_total=-total
    )
    db.add(db_item)
    
    # 4. Write stock movement
    db_movement = StockMovement(
        id=uuid.uuid4(),
        medicine_id=med_uuid,
        movement_type="return",
        quantity_before=qty_before,
        quantity_change=ret.returned_quantity,
        quantity_after=qty_after,
        reference_id=db_sale.id,
        reference_type="sale",
        notes=f"Return from {ret.customer_name}. Invoice {inv_num}",
        performed_by=current_user.id,
        created_at=datetime.now(timezone.utc)
    )
    db.add(db_movement)
    
    await db.commit()
    
    return {"detail": "Return processed successfully", "invoice_number": inv_num, "new_quantity": qty_after}
