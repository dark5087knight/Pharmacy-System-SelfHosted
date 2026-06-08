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
from app.dependencies import get_current_user
from app.models import Staff, PurchaseOrder, PurchaseOrderItem, Medicine, StockMovement
from app.procurement.schemas import PurchaseOrderCreate, PurchaseOrderResponse, PurchaseOrderBase

router = APIRouter(tags=["Procurement"])

def format_purchase_order(po: PurchaseOrder) -> dict:
    items = [{
        "medicineId": str(it.medicine_id),
        "quantity": it.quantity_ordered,
        "unitCost": float(it.unit_cost)
    } for it in po.items]
    
    return {
        "id": str(po.id),
        "poNumber": po.po_number,
        "supplierId": str(po.supplier_id),
        "status": po.status,
        "total": float(po.total),
        "createdAt": po.created_at.isoformat(),
        "expectedAt": po.expected_at.isoformat() if po.expected_at else None,
        "receivedAt": po.received_at.isoformat() if po.received_at else None,
        "items": items
    }

@router.get("/purchase-orders", response_model=List[PurchaseOrderResponse])
async def read_purchase_orders(
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    stmt = select(PurchaseOrder).options(selectinload(PurchaseOrder.items))
    result = await db.execute(stmt)
    pos = result.scalars().all()
    return [format_purchase_order(po) for po in pos]


@router.post("/purchase-orders", response_model=PurchaseOrderResponse)
async def create_purchase_order(
    po: PurchaseOrderCreate, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    po_uuid = to_uuid(po.id, "purchase_order")
    
    # Check if PO number already exists
    check_stmt = select(PurchaseOrder).filter(
        PurchaseOrder.po_number == po.po_number
    )
    check_res = await db.execute(check_stmt)
    if check_res.scalars().first():
        raise HTTPException(status_code=400, detail="PO number already exists.")

    db_po = PurchaseOrder(
        id=po_uuid,
        po_number=po.po_number,
        supplier_id=to_uuid(po.supplier_id, "supplier"),
        status=po.status,
        total=po.total,
        created_at=datetime.fromisoformat(po.created_at.replace("Z", "+00:00")),
        expected_at=datetime.fromisoformat(po.expected_at.replace("Z", "+00:00")) if po.expected_at else None,
        received_at=datetime.fromisoformat(po.received_at.replace("Z", "+00:00")) if po.received_at else None,
        created_by=current_user.id
    )
    db.add(db_po)
    await db.flush()

    for item in po.items:
        med_uuid = to_uuid(item.medicine_id, "medicine")
        
        db_item = PurchaseOrderItem(
            id=uuid.uuid4(),
            purchase_order_id=db_po.id,
            medicine_id=med_uuid,
            quantity_ordered=item.quantity,
            quantity_received=item.quantity if po.status == "received" else 0,
            unit_cost=item.unit_cost,
            line_total=round(item.quantity * float(item.unit_cost), 2)
        )
        db.add(db_item)
        
        # If received immediately, update stock
        if po.status == "received":
            med_stmt = select(Medicine).filter(Medicine.id == med_uuid)
            med_res = await db.execute(med_stmt)
            db_med = med_res.scalars().first()
            if db_med:
                qty_before = db_med.quantity
                db_med.quantity += item.quantity
                qty_after = db_med.quantity
                
                db_movement = StockMovement(
                    id=uuid.uuid4(),
                    medicine_id=med_uuid,
                    movement_type="purchase",
                    quantity_before=qty_before,
                    quantity_change=item.quantity,
                    quantity_after=qty_after,
                    reference_id=db_po.id,
                    reference_type="purchase_order",
                    notes=f"Stock received PO {db_po.po_number}",
                    performed_by=current_user.id,
                    created_at=datetime.now(timezone.utc)
                )
                db.add(db_movement)

    await db.commit()
    
    # Reload with items loaded
    reload_stmt = select(PurchaseOrder).filter(PurchaseOrder.id == db_po.id).options(selectinload(PurchaseOrder.items))
    reload_res = await db.execute(reload_stmt)
    return format_purchase_order(reload_res.scalars().first())


@router.put("/purchase-orders/{id}", response_model=PurchaseOrderResponse)
async def update_purchase_order(
    id: str, 
    po: PurchaseOrderBase, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    po_uuid = to_uuid(id, "purchase_order")
    stmt = select(PurchaseOrder).filter(PurchaseOrder.id == po_uuid).options(selectinload(PurchaseOrder.items))
    result = await db.execute(stmt)
    db_po = result.scalars().first()
    
    if not db_po:
        raise HTTPException(status_code=404, detail="Purchase order not found")
        
    old_status = db_po.status
    db_po.status = po.status
    db_po.total = po.total
    if po.expected_at:
        db_po.expected_at = datetime.fromisoformat(po.expected_at.replace("Z", "+00:00"))
    if po.received_at:
        db_po.received_at = datetime.fromisoformat(po.received_at.replace("Z", "+00:00"))
        
    # If transitioned to received, execute inventory update
    if po.status == "received" and old_status != "received":
        db_po.approved_by = current_user.id
        for item in db_po.items:
            item.quantity_received = item.quantity_ordered
            db.add(item)
            
            # Update stock
            med_stmt = select(Medicine).filter(Medicine.id == item.medicine_id)
            med_res = await db.execute(med_stmt)
            db_med = med_res.scalars().first()
            if db_med:
                qty_before = db_med.quantity
                db_med.quantity += item.quantity_ordered
                qty_after = db_med.quantity
                
                db_movement = StockMovement(
                    id=uuid.uuid4(),
                    medicine_id=item.medicine_id,
                    movement_type="purchase",
                    quantity_before=qty_before,
                    quantity_change=item.quantity_ordered,
                    quantity_after=qty_after,
                    reference_id=db_po.id,
                    reference_type="purchase_order",
                    notes=f"Stock received PO {db_po.po_number}",
                    performed_by=current_user.id,
                    created_at=datetime.now(timezone.utc)
                )
                db.add(db_movement)
                
    db.add(db_po)
    await db.commit()
    
    # Reload with items loaded
    reload_stmt = select(PurchaseOrder).filter(PurchaseOrder.id == db_po.id).options(selectinload(PurchaseOrder.items))
    reload_res = await db.execute(reload_stmt)
    return format_purchase_order(reload_res.scalars().first())
