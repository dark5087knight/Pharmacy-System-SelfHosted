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
from app.auth.service import hash_password
from app.models import Staff, Role, Permission, UserRole
from app.staff.schemas import StaffMemberCreate, StaffMemberResponse, RoleCreate, RoleResponse, RoleBase

router = APIRouter(tags=["Staff & RBAC"])

# --- STAFF ENDPOINTS ---

@router.get("/staff", response_model=List[StaffMemberResponse])
async def read_staff(
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(require_permission("manage_users"))
):
    stmt = select(Staff).filter(Staff.deleted_at == None).options(selectinload(Staff.roles))
    result = await db.execute(stmt)
    staff_members = result.scalars().all()
    
    results = []
    for s in staff_members:
        role_name = s.roles[0].name if s.roles else "cashier"
        results.append({
            "id": str(s.id),
            "name": s.name,
            "username": s.username,
            "email": s.email or "",
            "role": role_name,
            "status": s.status,
            "shift": s.shift,
            "joinedAt": s.joined_at.isoformat(),
            "lastSeen": s.last_seen_at.isoformat() if s.last_seen_at else ""
        })
    return results


@router.post("/staff", response_model=StaffMemberResponse)
async def create_staff_member(
    st: StaffMemberCreate, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(require_permission("manage_users"))
):
    staff_uuid = to_uuid(st.id, "staff")
    
    # Check if username is already registered
    check_stmt = select(Staff).filter(Staff.username == st.username, Staff.deleted_at == None)
    check_res = await db.execute(check_stmt)
    if check_res.scalars().first():
        raise HTTPException(status_code=400, detail="Username is already registered.")

    password_hash = ""
    if st.password:
        password_hash = hash_password(st.password)

    db_st = Staff(
        id=staff_uuid,
        name=st.name,
        username=st.username,
        email=st.email,
        password_hash=password_hash,
        status=st.status,
        shift=st.shift,
        joined_at=datetime.fromisoformat(st.joined_at.replace("Z", "+00:00")) if st.joined_at else datetime.now(timezone.utc),
        last_seen_at=None,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc)
    )
    
    # Resolve Role
    role_stmt = select(Role).filter(Role.name == st.role)
    role_res = await db.execute(role_stmt)
    role = role_res.scalars().first()
    if role:
        db_st.roles.append(role)
        
    db.add(db_st)
    await db.commit()
    await db.refresh(db_st)
    
    return {
        "id": str(db_st.id),
        "name": db_st.name,
        "username": db_st.username,
        "email": db_st.email or "",
        "role": st.role,
        "status": db_st.status,
        "shift": db_st.shift,
        "joinedAt": db_st.joined_at.isoformat(),
        "lastSeen": ""
    }


@router.put("/staff/{id}", response_model=StaffMemberResponse)
async def update_staff_member(
    id: str, 
    st: StaffMemberCreate, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(require_permission("manage_users"))
):
    staff_uuid = to_uuid(id, "staff")
    
    stmt = select(Staff).filter(Staff.id == staff_uuid, Staff.deleted_at == None).options(selectinload(Staff.roles))
    result = await db.execute(stmt)
    db_st = result.scalars().first()
    
    if not db_st:
        raise HTTPException(status_code=404, detail="Staff member not found")
        
    db_st_role = db_st.roles[0].name if db_st.roles else "cashier"
    if db_st_role == "admin" or db_st.name == "Admin":
        if st.username != db_st.username:
            raise HTTPException(status_code=403, detail="Cannot change admin username.")
        if db_st_role == "admin" and st.role != "admin":
            raise HTTPException(status_code=403, detail="Cannot change admin role.")
        if db_st.name == "Admin":
            if st.name != db_st.name:
                raise HTTPException(status_code=403, detail="Cannot change admin name.")

    db_st.name = st.name
    db_st.username = st.username
    db_st.email = st.email
    if st.password:
        db_st.password_hash = hash_password(st.password)
    db_st.status = st.status
    db_st.shift = st.shift
    db_st.updated_at = datetime.now(timezone.utc)
    
    # Update Role
    role_stmt = select(Role).filter(Role.name == st.role)
    role_res = await db.execute(role_stmt)
    role = role_res.scalars().first()
    if role:
        db_st.roles = [role]
        
    db.add(db_st)
    await db.commit()
    await db.refresh(db_st)
    
    return {
        "id": str(db_st.id),
        "name": db_st.name,
        "username": db_st.username,
        "email": db_st.email or "",
        "role": st.role,
        "status": db_st.status,
        "shift": db_st.shift,
        "joinedAt": db_st.joined_at.isoformat(),
        "lastSeen": db_st.last_seen_at.isoformat() if db_st.last_seen_at else ""
    }


@router.delete("/staff/{id}", response_model=StaffMemberResponse)
async def delete_staff_member(
    id: str, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(require_permission("manage_users"))
):
    staff_uuid = to_uuid(id, "staff")
    stmt = select(Staff).filter(Staff.id == staff_uuid, Staff.deleted_at == None).options(selectinload(Staff.roles))
    result = await db.execute(stmt)
    db_st = result.scalars().first()
    
    if not db_st:
        raise HTTPException(status_code=404, detail="Staff member not found")
        
    db_st_role = db_st.roles[0].name if db_st.roles else "cashier"
    if db_st_role == "admin" or db_st.name == "Admin":
        raise HTTPException(status_code=403, detail="Cannot delete admin account.")

    role_name = db_st.roles[0].name if db_st.roles else "cashier"
    res = {
        "id": str(db_st.id),
        "name": db_st.name,
        "username": db_st.username,
        "email": db_st.email or "",
        "role": role_name,
        "status": db_st.status,
        "shift": db_st.shift,
        "joinedAt": db_st.joined_at.isoformat(),
        "lastSeen": db_st.last_seen_at.isoformat() if db_st.last_seen_at else ""
    }
    
    db_st.deleted_at = datetime.now(timezone.utc)
    db.add(db_st)
    await db.commit()
    return res


# --- ROLE ENDPOINTS ---

@router.get("/roles", response_model=List[RoleResponse])
async def read_roles(
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(require_permission("manage_roles"))
):
    stmt = select(Role).options(selectinload(Role.permissions))
    result = await db.execute(stmt)
    roles = result.scalars().all()
    
    return [{
        "id": str(r.id),
        "name": r.name,
        "description": r.description or "",
        "permissions": [p.code for p in r.permissions]
    } for r in roles]


@router.post("/roles", response_model=RoleResponse)
async def create_role(
    r: RoleCreate, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(require_permission("manage_roles"))
):
    role_uuid = to_uuid(r.id, "role")
    
    # Check if role name already exists
    check_stmt = select(Role).filter(Role.name == r.name)
    check_res = await db.execute(check_stmt)
    if check_res.scalars().first():
        raise HTTPException(status_code=400, detail="Role name already exists.")

    db_r = Role(
        id=role_uuid,
        name=r.name,
        description=r.description,
        is_system=False,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc)
    )
    
    # Map Permissions
    perm_stmt = select(Permission).filter(Permission.code.in_(r.permissions))
    perm_res = await db.execute(perm_stmt)
    perms = perm_res.scalars().all()
    db_r.permissions = perms
    
    db.add(db_r)
    await db.commit()
    await db.refresh(db_r)
    
    return {
        "id": str(db_r.id),
        "name": db_r.name,
        "description": db_r.description,
        "permissions": [p.code for p in db_r.permissions]
    }


@router.put("/roles/{id}", response_model=RoleResponse)
async def update_role(
    id: str, 
    r: RoleBase, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(require_permission("manage_roles"))
):
    role_uuid = to_uuid(id, "role")
    stmt = select(Role).filter(Role.id == role_uuid).options(selectinload(Role.permissions))
    result = await db.execute(stmt)
    db_r = result.scalars().first()
    
    if not db_r:
        raise HTTPException(status_code=404, detail="Role not found")
        
    db_r.name = r.name
    db_r.description = r.description
    db_r.updated_at = datetime.now(timezone.utc)
    
    # Update Permissions
    perm_stmt = select(Permission).filter(Permission.code.in_(r.permissions))
    perm_res = await db.execute(perm_stmt)
    perms = perm_res.scalars().all()
    db_r.permissions = perms
    
    db.add(db_r)
    await db.commit()
    await db.refresh(db_r)
    
    return {
        "id": str(db_r.id),
        "name": db_r.name,
        "description": db_r.description,
        "permissions": [p.code for p in db_r.permissions]
    }


@router.delete("/roles/{id}", response_model=RoleResponse)
async def delete_role(
    id: str, 
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(require_permission("manage_roles"))
):
    role_uuid = to_uuid(id, "role")
    stmt = select(Role).filter(Role.id == role_uuid).options(selectinload(Role.permissions))
    result = await db.execute(stmt)
    db_r = result.scalars().first()
    
    if not db_r:
        raise HTTPException(status_code=404, detail="Role not found")
        
    if db_r.is_system:
        raise HTTPException(status_code=400, detail="Built-in system roles cannot be deleted.")
        
    res = {
        "id": str(db_r.id),
        "name": db_r.name,
        "description": db_r.description,
        "permissions": [p.code for p in db_r.permissions]
    }
    
    await db.delete(db_r)
    await db.commit()
    return res
