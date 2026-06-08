from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from pydantic import BaseModel
from typing import Optional, Any, Dict
from datetime import datetime, timezone

from app.shared.database import get_db
from app.shared.responses import success_response
from app.dependencies import get_current_user, require_permission
from app.models import PharmacySettings, Staff

router = APIRouter(prefix="/pharmacy", tags=["Pharmacy Settings"])

class PharmacySettingsUpdate(BaseModel):
    name: str
    phone: Optional[str] = None
    address: Optional[str] = None
    country: str
    timezone: str
    locale: str
    currency: str
    logo_url: Optional[str] = None
    settings: Optional[Dict[str, Any]] = None

@router.get("")
async def get_pharmacy_settings(
    db: AsyncSession = Depends(get_db),
    current_user: Staff = Depends(get_current_user)
):
    stmt = select(PharmacySettings).limit(1)
    result = await db.execute(stmt)
    settings_obj = result.scalars().first()
    if not settings_obj:
        # Create default settings if not exists
        settings_obj = PharmacySettings(
            name="My Pharmacy",
            country="IQ",
            timezone="Asia/Baghdad",
            locale="en",
            currency="IQD",
            settings={}
        )
        db.add(settings_obj)
        await db.commit()
        await db.refresh(settings_obj)
    
    return {
        "id": str(settings_obj.id),
        "name": settings_obj.name,
        "phone": settings_obj.phone or "",
        "address": settings_obj.address or "",
        "country": settings_obj.country,
        "timezone": settings_obj.timezone,
        "locale": settings_obj.locale,
        "currency": settings_obj.currency,
        "logo_url": settings_obj.logo_url or "",
        "settings": settings_obj.settings
    }

@router.put("")
async def update_pharmacy_settings(
    payload: PharmacySettingsUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: Staff = Depends(require_permission("manage_finance"))  # restrict to admin-level permissions
):
    stmt = select(PharmacySettings).limit(1)
    result = await db.execute(stmt)
    settings_obj = result.scalars().first()
    if not settings_obj:
        raise HTTPException(status_code=404, detail="Settings not found")
        
    settings_obj.name = payload.name
    settings_obj.phone = payload.phone
    settings_obj.address = payload.address
    settings_obj.country = payload.country
    settings_obj.timezone = payload.timezone
    settings_obj.locale = payload.locale
    settings_obj.currency = payload.currency
    settings_obj.logo_url = payload.logo_url
    if payload.settings is not None:
        settings_obj.settings = payload.settings
    settings_obj.updated_at = datetime.now(timezone.utc)
    
    db.add(settings_obj)
    await db.commit()
    await db.refresh(settings_obj)
    
    return success_response({
        "detail": "Pharmacy settings updated successfully.",
        "settings": {
            "id": str(settings_obj.id),
            "name": settings_obj.name,
            "phone": settings_obj.phone or "",
            "address": settings_obj.address or "",
            "country": settings_obj.country,
            "timezone": settings_obj.timezone,
            "locale": settings_obj.locale,
            "currency": settings_obj.currency,
            "logo_url": settings_obj.logo_url or "",
            "settings": settings_obj.settings
        }
    })
