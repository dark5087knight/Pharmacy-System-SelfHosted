from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Response, Cookie, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import func
from datetime import datetime, timezone
import uuid

from app.shared.database import get_db
from app.shared.responses import success_response
from app.auth.service import (
    hash_password, verify_password, create_access_token, create_refresh_token, decode_token
)
from app.auth.schemas import LoginRequest, TokenResponse, TokenUserResponse
from app.dependencies import get_current_user
from app.models import Branch, Staff, Role, Permission, UserRole, PharmacySettings

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.get("/info")
async def get_system_info(db: AsyncSession = Depends(get_db)):
    stmt = select(PharmacySettings).limit(1)
    result = await db.execute(stmt)
    settings_obj = result.scalars().first()
    settings_id = str(settings_obj.id) if settings_obj else "unknown"
    pharmacy_name = settings_obj.name if settings_obj else "My Pharmacy"
    return {
        "status": "online",
        "settings_id": settings_id,
        "name": pharmacy_name
    }

@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, response: Response, db: AsyncSession = Depends(get_db)):
    stmt = select(Staff).filter(Staff.username == payload.username, Staff.deleted_at == None).options(
        selectinload(Staff.roles).selectinload(Role.permissions)
    )
    result = await db.execute(stmt)
    staff = result.scalars().first()
    
    if not staff:
        raise HTTPException(status_code=401, detail="Invalid username or password.")
        
    if staff.status != "active":
        raise HTTPException(status_code=403, detail="Staff account is inactive.")

    # Verify password (handles SHA-256 fallback)
    if not verify_password(payload.password, staff.password_hash):
        raise HTTPException(status_code=401, detail="Invalid username or password.")

    # Upgrade to bcrypt if password hash is SHA-256
    if len(staff.password_hash) == 64:
        staff.password_hash = hash_password(payload.password)
        db.add(staff)

    # Update last seen timestamp
    staff.last_seen_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(staff)

    # Generate JWT tokens
    role_name = staff.roles[0].name if staff.roles else "cashier"
    permissions = []
    if staff.roles:
        permissions = [p.code for p in staff.roles[0].permissions]

    token_data = {
        "sub": str(staff.id),
        "role": role_name,
        "perms": permissions
    }

    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)

    # Set HttpOnly cookie for web/React client compatibility
    response.set_cookie(
        key="session_id",
        value=access_token,
        httponly=True,
        samesite="lax",
        secure=False,  # Set to True in production
        max_age=100 * 365 * 24 * 3600,  # 100 years
    )

    # Query pharmacy settings
    pharmacy_stmt = select(PharmacySettings).limit(1)
    pharmacy_res = await db.execute(pharmacy_stmt)
    pharmacy_row = pharmacy_res.scalars().first()
    pharmacy_name = pharmacy_row.name if pharmacy_row else "My Pharmacy"

    # Return standard response matching expected client parameters
    user_info = {
        "id": str(staff.id),
        "name": staff.name,
        "username": staff.username,
        "email": staff.email or "",
        "role": role_name,
        "status": staff.status,
        "shift": staff.shift,
        "joinedAt": staff.joined_at.isoformat(),
        "lastSeen": staff.last_seen_at.isoformat() if staff.last_seen_at else "",
        "pharmacyName": pharmacy_name,
        "pharmacySettingsId": str(pharmacy_row.id) if pharmacy_row else "default"
    }

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "session_token": access_token,  # Backward compatibility for Flutter client
        "user": user_info
    }


@router.post("/refresh")
async def refresh_token(response: Response, authorization: Optional[str] = Header(None)):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Invalid refresh token.")
    
    token = authorization[7:]
    try:
        payload = decode_token(token)
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid refresh token.")

    if payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Token is not a refresh token.")

    # Re-issue access token
    access_token_data = {
        "sub": payload.get("sub"),
        "role": payload.get("role"),
        "perms": payload.get("perms")
    }

    new_access_token = create_access_token(access_token_data)

    response.set_cookie(
        key="session_id",
        value=new_access_token,
        httponly=True,
        samesite="lax",
        secure=False,
        max_age=100 * 365 * 24 * 3600,  # 100 years
    )

    return {
        "access_token": new_access_token,
        "session_token": new_access_token
    }


@router.post("/logout")
async def logout(response: Response):
    response.delete_cookie(key="session_id")
    return success_response({"detail": "Logged out successfully."})


@router.get("/me")
async def get_me(current_user: Staff = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    role_name = current_user.roles[0].name if current_user.roles else "cashier"
    
    # Query pharmacy settings
    pharmacy_stmt = select(PharmacySettings).limit(1)
    pharmacy_res = await db.execute(pharmacy_stmt)
    pharmacy_row = pharmacy_res.scalars().first()
    pharmacy_name = pharmacy_row.name if pharmacy_row else "My Pharmacy"
    
    return {
        "id": str(current_user.id),
        "name": current_user.name,
        "username": current_user.username,
        "email": current_user.email or "",
        "role": role_name,
        "status": current_user.status,
        "shift": current_user.shift,
        "joinedAt": current_user.joined_at.isoformat(),
        "lastSeen": current_user.last_seen_at.isoformat() if current_user.last_seen_at else "",
        "pharmacyName": pharmacy_name,
        "pharmacySettingsId": str(pharmacy_row.id) if pharmacy_row else "default"
    }


@router.get("/tenant-status")
@router.get("/status")
async def get_tenant_status(
    db: AsyncSession = Depends(get_db),
    current_user: Staff = Depends(get_current_user)
):
    # Count other staff (excluding current user)
    staff_count_stmt = select(func.count()).select_from(Staff).filter(
        Staff.id != current_user.id,
        Staff.deleted_at == None
    )
    staff_res = await db.execute(staff_count_stmt)
    staff_count = staff_res.scalar() or 0
    
    # Count inventory medicines
    from app.models import Medicine
    med_count_stmt = select(func.count()).select_from(Medicine).filter(
        Medicine.deleted_at == None
    )
    med_res = await db.execute(med_count_stmt)
    med_count = med_res.scalar() or 0
    
    # Count suppliers
    from app.models import Supplier
    sup_count_stmt = select(func.count()).select_from(Supplier).filter(
        Supplier.deleted_at == None
    )
    sup_res = await db.execute(sup_count_stmt)
    sup_count = sup_res.scalar() or 0
    
    is_empty = (staff_count == 0 and med_count == 0 and sup_count == 0)
    
    return {
        "is_empty": is_empty,
        "staff_count": staff_count,
        "med_count": med_count,
        "sup_count": sup_count
    }
