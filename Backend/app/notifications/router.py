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
from app.models import Staff, Notification
from app.notifications.schemas import NotificationCreate, NotificationResponse

router = APIRouter(tags=["Notifications"])

def format_notification(n: Notification) -> dict:
    return {
        "id": str(n.id),
        "title": n.title,
        "body": n.body or "",
        "category": n.category,
        "priority": n.priority,
        "read": n.read,
        "at": n.created_at.isoformat()
    }

@router.get("/notifications", response_model=List[NotificationResponse])
async def read_notifications(
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    stmt = select(Notification)
    result = await db.execute(stmt)
    notifications = result.scalars().all()
    return [format_notification(n) for n in notifications]


@router.put("/notifications/{id}", response_model=NotificationResponse)
async def update_notification(
    id: str, 
    payload: dict, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    read = payload.get("read")
    if read is None:
        raise HTTPException(status_code=400, detail="read field required")
        
    ntf_uuid = to_uuid(id, "notification")
    stmt = select(Notification).filter(Notification.id == ntf_uuid)
    result = await db.execute(stmt)
    db_ntf = result.scalars().first()
    
    if not db_ntf:
        raise HTTPException(status_code=404, detail="Notification not found")
        
    db_ntf.read = read
    db_ntf.read_at = datetime.now(timezone.utc) if read else None
    
    db.add(db_ntf)
    await db.commit()
    await db.refresh(db_ntf)
    return format_notification(db_ntf)


@router.post("/notifications", response_model=NotificationResponse)
async def create_notification(
    ntf: NotificationCreate, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    ntf_uuid = to_uuid(ntf.id, "notification")
    
    db_ntf = Notification(
        id=ntf_uuid,
        staff_id=None, # default broadcast
        title=ntf.title,
        body=ntf.body,
        category=ntf.category,
        priority=ntf.priority,
        read=ntf.read,
        created_at=datetime.fromisoformat(ntf.at.replace("Z", "+00:00")) if ntf.at else datetime.now(timezone.utc)
    )
    db.add(db_ntf)
    await db.commit()
    await db.refresh(db_ntf)
    return format_notification(db_ntf)
