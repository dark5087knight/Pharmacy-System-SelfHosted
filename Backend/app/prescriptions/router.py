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
from app.models import Staff, Prescription, PrescriptionItem
from app.prescriptions.schemas import PrescriptionCreate, PrescriptionResponse

router = APIRouter(tags=["Prescriptions"])

def format_prescription(p: Prescription) -> dict:
    return {
        "id": str(p.id),
        "customerId": str(p.customer_id),
        "doctorName": p.doctor_name,
        "doctorLicense": p.doctor_license,
        "issuedAt": p.issued_at.isoformat(),
        "status": p.status,
        "imageUrl": p.image_url,
        "notes": p.notes,
        "refillsRemaining": p.refills_remaining,
        "items": [{"medicineId": str(it.medicine_id), "quantity": it.quantity, "dosage": it.dosage} for it in p.items]
    }

@router.get("/prescriptions", response_model=List[PrescriptionResponse])
async def read_prescriptions(
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    stmt = select(Prescription).options(selectinload(Prescription.items))
    result = await db.execute(stmt)
    prescriptions = result.scalars().all()
    return [format_prescription(p) for p in prescriptions]


@router.post("/prescriptions", response_model=PrescriptionResponse)
async def create_prescription(
    p: PrescriptionCreate, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    rx_uuid = to_uuid(p.id, "prescription")
    
    db_rx = Prescription(
        id=rx_uuid,
        customer_id=to_uuid(p.customer_id, "customer"),
        doctor_name=p.doctor_name,
        doctor_license=p.doctor_license,
        issued_at=datetime.fromisoformat(p.issued_at.replace("Z", "+00:00")),
        status=p.status,
        image_url=p.image_url,
        notes=p.notes,
        refills_remaining=p.refills_remaining,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
        created_by=current_user.id
    )
    db.add(db_rx)
    await db.flush() # flush to generate ID for prescription_items FK

    for item in p.items:
        db_item = PrescriptionItem(
            id=uuid.uuid4(),
            prescription_id=db_rx.id,
            medicine_id=to_uuid(item.medicine_id, "medicine"),
            quantity=item.quantity,
            dosage=item.dosage,
            instructions=""
        )
        db.add(db_item)
        
    await db.commit()
    
    # Reload with items loaded
    stmt = select(Prescription).filter(Prescription.id == db_rx.id).options(selectinload(Prescription.items))
    res = await db.execute(stmt)
    return format_prescription(res.scalars().first())


@router.put("/prescriptions/{id}", response_model=PrescriptionResponse)
async def update_prescription_status(
    id: str, 
    payload: dict, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    status = payload.get("status")
    if not status:
        raise HTTPException(status_code=400, detail="status field required")
        
    rx_uuid = to_uuid(id, "prescription")
    stmt = select(Prescription).filter(Prescription.id == rx_uuid).options(selectinload(Prescription.items))
    result = await db.execute(stmt)
    db_rx = result.scalars().first()
    
    if not db_rx:
        raise HTTPException(status_code=404, detail="Prescription not found")
        
    db_rx.status = status
    db_rx.updated_at = datetime.now(timezone.utc)
    if status == "verified":
        db_rx.verified_by = current_user.id
        
    db.add(db_rx)
    await db.commit()
    await db.refresh(db_rx)
    return format_prescription(db_rx)
