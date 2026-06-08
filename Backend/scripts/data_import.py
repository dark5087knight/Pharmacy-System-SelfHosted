import sqlite3
import asyncio
import uuid
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.shared.database import AsyncSessionLocal
from app.shared.utils import to_uuid
from app.models import Medicine, Customer, Supplier, Staff, Tenant, Plan

# Path to the source SQLite database
SQLITE_DB_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "pharmacy_backend", "pharmacy.db"))

async def migrate_data():
    if not os.path.exists(SQLITE_DB_PATH):
        print(f"Source SQLite database not found at {SQLITE_DB_PATH}. Skipping migration.")
        return

    print(f"Connecting to source SQLite database: {SQLITE_DB_PATH}")
    sqlite_conn = sqlite3.connect(SQLITE_DB_PATH)
    sqlite_conn.row_factory = sqlite3.Row
    cursor = sqlite_conn.cursor()

    async with AsyncSessionLocal() as pg_db:
        # Resolve Tenant
        from sqlalchemy import select
        tenant_res = await pg_db.execute(select(Tenant).limit(1))
        tenant = tenant_res.scalars().first()
        if not tenant:
            print("No tenant exists in PostgreSQL. Run seeding first to set up the default tenant.")
            return
        
        tenant_id = tenant.id
        print(f"Migrating data into Tenant: {tenant.name} ({tenant_id})")

        # 1. Migrate Suppliers
        try:
            cursor.execute("SELECT * FROM suppliers")
            rows = cursor.fetchall()
            for r in rows:
                sup_uuid = to_uuid(str(r["id"]), "supplier")
                # Check if exists
                chk = await pg_db.get(Supplier, sup_uuid)
                if not chk:
                    db_sup = Supplier(
                        id=sup_uuid,
                        tenant_id=tenant_id,
                        name=r["name"],
                        company=r["company"],
                        email=r["email"] if "email" in r.keys() else None,
                        phone=r["phone"] if "phone" in r.keys() else "",
                        address=r["address"] if "address" in r.keys() else "",
                        rating=r["rating"] if "rating" in r.keys() else 5.0,
                        status="active"
                    )
                    pg_db.add(db_sup)
            await pg_db.commit()
            print(f"Migrated {len(rows)} suppliers.")
        except Exception as e:
            print(f"Suppliers migration skipped or failed: {e}")

        # 2. Migrate Customers
        try:
            cursor.execute("SELECT * FROM customers")
            rows = cursor.fetchall()
            for r in rows:
                cust_uuid = to_uuid(str(r["id"]), "customer")
                chk = await pg_db.get(Customer, cust_uuid)
                if not chk:
                    db_cust = Customer(
                        id=cust_uuid,
                        tenant_id=tenant_id,
                        name=r["name"],
                        phone=r["phone"],
                        email=r["email"] if "email" in r.keys() else None,
                        status="active"
                    )
                    pg_db.add(db_cust)
            await pg_db.commit()
            print(f"Migrated {len(rows)} customers.")
        except Exception as e:
            print(f"Customers migration skipped or failed: {e}")

        # 3. Migrate Medicines
        try:
            cursor.execute("SELECT * FROM medicines")
            rows = cursor.fetchall()
            for r in rows:
                med_uuid = to_uuid(str(r["id"]), "medicine")
                chk = await pg_db.get(Medicine, med_uuid)
                if not chk:
                    # Resolve category and supplier UUIDs
                    supplier_id = None
                    if "supplier_id" in r.keys() and r["supplier_id"]:
                        supplier_id = to_uuid(str(r["supplier_id"]), "supplier")

                    db_med = Medicine(
                        id=med_uuid,
                        tenant_id=tenant_id,
                        name=r["name"],
                        generic_name=r["genericName"] if "genericName" in r.keys() else r.get("generic_name", ""),
                        brand=r["brand"] if "brand" in r.keys() else "",
                        barcode=r["barcode"] if "barcode" in r.keys() else None,
                        sku=r["sku"] if "sku" in r.keys() else None,
                        expiry_date=r["expiryDate"] if "expiryDate" in r.keys() else r.get("expiry_date"),
                        quantity=r["quantity"],
                        unit=r["unit"] if "unit" in r.keys() else "tablet",
                        purchase_price=r["purchasePrice"] if "purchasePrice" in r.keys() else r.get("purchase_price", 0.0),
                        selling_price=r["sellingPrice"] if "sellingPrice" in r.keys() else r.get("selling_price", 0.0),
                        supplier_id=supplier_id,
                        status="active"
                    )
                    pg_db.add(db_med)
            await pg_db.commit()
            print(f"Migrated {len(rows)} medicines.")
        except Exception as e:
            print(f"Medicines migration skipped or failed: {e}")

    sqlite_conn.close()
    print("Migration finished!")

if __name__ == "__main__":
    asyncio.run(migrate_data())
