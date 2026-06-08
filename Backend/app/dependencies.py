from fastapi import Depends, Cookie, Header, Request, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import text
from typing import Optional
import uuid

from app.shared.database import get_db
from app.shared.exceptions import AuthException, PermissionException
from app.auth.service import decode_token
from app.models import Staff, Role

async def get_current_user(
    request: Request,
    session_id: Optional[str] = Cookie(None),
    authorization: Optional[str] = Header(None),
    x_session_id: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
) -> Staff:
    """
    Extract JWT token from headers or cookies, decode it, and load the Staff member.
    """
    token = None
    
    # 1. Try to get token from Authorization header
    if authorization and authorization.lower().startswith("bearer "):
        token = authorization[7:]
    
    # 2. Try to get token from session_id cookie
    elif session_id:
        # Check if cookie contains "session_id=" prefix
        if session_id.startswith("session_id="):
            token = session_id.replace("session_id=", "")
        else:
            token = session_id
            
    # 3. Try to get token from custom header
    elif x_session_id:
        token = x_session_id

    if not token:
        raise AuthException("Unauthorized. No session token provided.")

    # Decode JWT token
    try:
        payload = decode_token(token)
    except ValueError as e:
        raise AuthException(f"Unauthorized. {str(e)}")

    if payload.get("type") != "access":
        raise AuthException("Unauthorized. Invalid token type.")

    staff_id_str = payload.get("sub")
    
    if not staff_id_str:
        raise AuthException("Unauthorized. Invalid token payload structure.")

    try:
        staff_uuid = uuid.UUID(staff_id_str)
    except ValueError:
        raise AuthException("Unauthorized. Invalid UUID format in token claims.")

    # Fetch the staff member along with roles and permissions
    stmt = select(Staff).filter(Staff.id == staff_uuid, Staff.deleted_at == None).options(
        selectinload(Staff.roles).selectinload(Role.permissions)
    )
    result = await db.execute(stmt)
    staff = result.scalars().first()
    
    if not staff:
        raise AuthException("Unauthorized. Staff member not found.")
        
    if staff.status != "active":
        raise AuthException("Unauthorized. Staff account is inactive.")

    return staff

def require_permission(permission: str):
    """Factory dependency to enforce specific RBAC permissions."""
    async def dependency(current_user: Staff = Depends(get_current_user)) -> Staff:
        user_permissions = []
        for role in current_user.roles:
            user_permissions.extend([p.code for p in role.permissions])
            
        if permission not in user_permissions:
            raise PermissionException(f"Forbidden. Missing permission: {permission}")
            
        return current_user
    return dependency
