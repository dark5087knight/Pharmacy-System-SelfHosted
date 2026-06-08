from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List
from datetime import datetime, timezone
import uuid

from app.shared.database import get_db
from app.shared.utils import to_uuid
from app.shared.responses import success_response
from app.dependencies import get_current_user, require_permission
from app.models import Staff, Activity, AuditLog
from app.audit.schemas import ActivityEventCreate, ActivityEventResponse

router = APIRouter(tags=["Activities & Audit"])

@router.get("/activities", response_model=List[ActivityEventResponse])
async def read_activities(
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(require_permission("view_reports"))
):
    # Perform outer join with Staff to resolve actor name in a single query
    stmt = (
        select(Activity, Staff.name)
        .outerjoin(Staff, Activity.actor_id == Staff.id)
        .order_by(Activity.created_at.desc())
    )
    result = await db.execute(stmt)
    
    results = []
    for act, actor_name in result.all():
        results.append({
            "id": str(act.id),
            "type": act.type,
            "message": act.message,
            "actor": actor_name or "System",
            "at": act.created_at.isoformat(),
            "severity": act.severity
        })
    return results


@router.post("/activities", response_model=ActivityEventResponse)
async def create_activity_event(
    act: ActivityEventCreate, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(get_current_user)
):
    # Try to find actor by name
    actor_stmt = select(Staff).filter(
        Staff.name == act.actor
    )
    actor_res = await db.execute(actor_stmt)
    db_actor = actor_res.scalars().first()
    actor_id = db_actor.id if db_actor else None

    db_act = Activity(
        id=to_uuid(act.id, "activity"),
        type=act.type,
        message=act.message,
        actor_id=actor_id,
        severity=act.severity or "info",
        activity_metadata={},
        created_at=datetime.fromisoformat(act.at.replace("Z", "+00:00")) if act.at else datetime.now(timezone.utc)
    )
    db.add(db_act)
    await db.commit()
    await db.refresh(db_act)
    
    return {
        "id": str(db_act.id),
        "type": db_act.type,
        "message": db_act.message,
        "actor": act.actor,
        "at": db_act.created_at.isoformat(),
        "severity": db_act.severity
    }


@router.get("/audit-logs")
async def read_audit_logs(
    db: AsyncSession = Depends(get_db),
    current_user: Staff = Depends(require_permission("view_reports"))
):
    stmt = select(AuditLog).order_by(AuditLog.created_at.desc())
    result = await db.execute(stmt)
    logs = result.scalars().all()
    
    return success_response([{
        "id": str(log.id),
        "action": log.action,
        "tableName": log.table_name,
        "recordId": str(log.record_id) if log.record_id else "",
        "oldValues": log.old_values,
        "newValues": log.new_values,
        "ipAddress": str(log.ip_address) if log.ip_address else "",
        "userAgent": log.user_agent or "",
        "createdAt": log.created_at.isoformat()
    } for log in logs])
