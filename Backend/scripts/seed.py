import asyncio
import uuid
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.shared.database import Base, AsyncSessionLocal, engine
from app.auth.service import hash_password
from app.models import PharmacySettings, Branch, Permission, Role, Staff

async def seed_clean_db(db: AsyncSession):
    # Check if pharmacy settings exist
    settings_check = await db.execute(select(PharmacySettings))
    if settings_check.scalars().first() is not None:
        print("Database already initialized. Skipping clean seeding.")
        return

    print("Running clean seeding for self-hosted database (no demo data)...")

    # 1. Pharmacy Settings
    settings = PharmacySettings(
        id=uuid.uuid4(),
        name="My Pharmacy",
        phone="+1 555-0199",
        address="100 Medical Plaza, Baghdad",
        country="IQ",
        timezone="Asia/Baghdad",
        locale="en",
        currency="IQD",
        logo_url=None,
        settings={},
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc)
    )
    db.add(settings)

    # 2. Branches
    branch = Branch(
        id=uuid.uuid4(),
        name="Main Branch",
        address="100 Medical Plaza, Baghdad",
        phone="+1 555-0199",
        is_main=True,
        status="active",
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc)
    )
    db.add(branch)
    await db.commit()
    await db.refresh(branch)

    # 3. Permissions catalog
    permissions_list = [
        ("manage_users", "staff", "Manage staff accounts"),
        ("manage_roles", "staff", "Manage user roles and permissions"),
        ("view_inventory", "medicines", "View inventory and medicines"),
        ("manage_inventory", "medicines", "Add, edit, or delete medicines"),
        ("view_sales", "sales", "View sales invoices and transactions"),
        ("manage_sales", "sales", "Create, edit, or refund sales transactions"),
        ("view_reports", "reports", "View sales, financial, and inventory reports"),
        ("manage_finance", "finance", "Manage payments and pricing"),
        ("view_prescriptions", "prescriptions", "View prescriptions"),
        ("manage_prescriptions", "prescriptions", "Verify and fulfill prescriptions"),
    ]
    
    perms = {}
    for code, mod, desc in permissions_list:
        p = Permission(
            id=uuid.uuid4(),
            code=code,
            module=mod,
            description=desc,
            created_at=datetime.now(timezone.utc)
        )
        db.add(p)
        perms[code] = p
    await db.commit()

    # Retrieve permissions again to ensure they are fully populated in session
    for code in perms:
        res = await db.execute(select(Permission).filter(Permission.code == code))
        perms[code] = res.scalars().first()

    # 4. Roles
    role_admin = Role(
        id=uuid.uuid4(),
        name="admin",
        description="Administrator - Full access",
        is_system=True,
        permissions=list(perms.values()),
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc)
    )

    role_pharmacist = Role(
        id=uuid.uuid4(),
        name="pharmacist",
        description="Pharmacist - Can manage inventory and prescriptions",
        is_system=True,
        permissions=[perms[c] for c in ["view_inventory", "manage_inventory", "view_sales", "manage_sales", "view_prescriptions", "manage_prescriptions"] if c in perms],
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc)
    )

    role_cashier = Role(
        id=uuid.uuid4(),
        name="cashier",
        description="Cashier - Can perform sales transactions",
        is_system=True,
        permissions=[perms[c] for c in ["view_inventory", "view_sales", "manage_sales", "view_prescriptions"] if c in perms],
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc)
    )

    role_manager = Role(
        id=uuid.uuid4(),
        name="manager",
        description="Store Manager - Can view reports and manage store operations",
        is_system=True,
        permissions=[perms[c] for c in ["view_inventory", "manage_inventory", "view_sales", "manage_sales", "view_reports", "view_prescriptions", "manage_prescriptions"] if c in perms],
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc)
    )

    db.add_all([role_admin, role_pharmacist, role_cashier, role_manager])
    await db.commit()
    await db.refresh(role_admin)

    # 5. Default Admin User (username: admin, password: admin)
    admin_password_hash = hash_password("admin")
    admin_staff = Staff(
        id=uuid.uuid4(),
        name="Admin User",
        username="admin",
        email="admin@pharm.co",
        password_hash=admin_password_hash,
        status="active",
        shift="morning",
        avatar_url=None,
        joined_at=datetime.now(timezone.utc),
        last_seen_at=None,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc)
    )
    admin_staff.roles.append(role_admin)
    db.add(admin_staff)
    await db.commit()

    print("Clean seeding completed successfully! Single admin account (admin / admin) created.")

async def create_tables():
    print("Creating database tables via SQLAlchemy metadata...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("Tables created successfully!")

async def async_main():
    await create_tables()
    async with AsyncSessionLocal() as session:
        await seed_clean_db(session)

if __name__ == "__main__":
    asyncio.run(async_main())
