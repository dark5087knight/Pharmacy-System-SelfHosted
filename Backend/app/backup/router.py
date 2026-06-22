import json
import uuid
from decimal import Decimal
from datetime import datetime, date, timezone
from typing import Dict, Any

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import text, inspect
import sqlalchemy as sa

from app.shared.database import get_db
from app.dependencies import get_current_user
from app.models import (
    Staff, PharmacySettings, Branch, Permission, Role, UserRole,
    MedicineCategory, Medicine, StockMovement, Customer,
    Prescription, PrescriptionItem, Sale, SaleItem, Payment,
    PurchaseOrder, PurchaseOrderItem, Notification, Activity, AuditLog,
    Supplier
)
from app.staff.models import role_permissions

router = APIRouter(prefix="/backup", tags=["Backup & Restore"])

TABLES_CONFIG = [
    ("pharmacy_settings", PharmacySettings),
    ("permissions", Permission),
    ("roles", Role),
    ("role_permissions", role_permissions),
    ("staff", Staff),
    ("user_roles", UserRole),
    ("branches", Branch),
    ("suppliers", Supplier),
    ("customers", Customer),
    ("medicine_categories", MedicineCategory),
    ("medicines", Medicine),
    ("stock_movements", StockMovement),
    ("prescriptions", Prescription),
    ("prescription_items", PrescriptionItem),
    ("sales", Sale),
    ("sale_items", SaleItem),
    ("payments", Payment),
    ("purchase_orders", PurchaseOrder),
    ("purchase_order_items", PurchaseOrderItem),
    ("notifications", Notification),
    ("activities", Activity),
    ("audit_logs", AuditLog),
]

def parse_val(col_type, val):
    if val is None:
        return None
    type_str = str(col_type).lower()
    if "uuid" in type_str:
        return uuid.UUID(val) if isinstance(val, str) else val
    elif "datetime" in type_str or "timestamp" in type_str:
        if isinstance(val, str):
            if val.endswith('Z'):
                val = val[:-1] + '+00:00'
            return datetime.fromisoformat(val)
        return val
    elif "date" in type_str:
        return date.fromisoformat(val[:10]) if isinstance(val, str) else val
    elif "numeric" in type_str or "decimal" in type_str:
        return Decimal(str(val))
    return val

def model_to_dict(obj):
    if obj is None:
        return None
    res = {}
    for attr in inspect(obj.__class__).mapper.column_attrs:
        val = getattr(obj, attr.key)
        if isinstance(val, uuid.UUID):
            val = str(val)
        elif isinstance(val, (datetime, date)):
            val = val.isoformat()
        elif isinstance(val, Decimal):
            val = float(val)
        col_name = attr.columns[0].name
        res[col_name] = val
    return res

@router.get("/export")
async def export_backup(
    db: AsyncSession = Depends(get_db),
    current_user: Staff = Depends(get_current_user)
):
    backup_data = {
        "version": "1.0",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "tables": {}
    }
    
    try:
        for table_name, model_or_table in TABLES_CONFIG:
            if model_or_table is role_permissions:
                res = await db.execute(role_permissions.select())
                rows = res.fetchall()
                backup_data["tables"][table_name] = [
                    {"role_id": str(r.role_id), "permission_id": str(r.permission_id)}
                    for r in rows
                ]
            else:
                stmt = select(model_or_table)
                res = await db.execute(stmt)
                rows = res.scalars().all()
                backup_data["tables"][table_name] = [model_to_dict(row) for row in rows]
                
        # Generate JSON content
        json_content = json.dumps(backup_data, indent=2, ensure_ascii=False)
        
        # Prepare filename
        date_str = datetime.now().strftime("%Y-%m-%d")
        filename = f"pharmacy_backup_{date_str}.json"
        
        # Create generator for StreamingResponse
        def iter_json():
            yield json_content.encode("utf-8")
            
        return StreamingResponse(
            iter_json(),
            media_type="application/json",
            headers={
                "Content-Disposition": f'attachment; filename="{filename}"'
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Backup export failed: {str(e)}")

@router.post("/import")
async def import_backup(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: Staff = Depends(get_current_user)
):
    try:
        contents = await file.read()
        backup_data = json.loads(contents.decode("utf-8"))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid backup file format: {str(e)}")
        
    if backup_data.get("version") != "1.0":
        raise HTTPException(status_code=400, detail="Unsupported backup version")
        
    tables_data = backup_data.get("tables", {})
    total_rows = 0
    tables_restored = 0
    
    try:
        # Truncate tables in reverse order to respect foreign key constraints
        table_names = [table_name for table_name, _ in reversed(TABLES_CONFIG)]
        await db.execute(text(f"TRUNCATE TABLE {', '.join(table_names)} CASCADE;"))
        await db.flush()
        
        # Re-insert tables in forward order
        for table_name, model_or_table in TABLES_CONFIG:
            rows = tables_data.get(table_name, [])
            if not rows:
                continue
                
            if model_or_table is role_permissions:
                for r in rows:
                    await db.execute(role_permissions.insert().values(
                        role_id=uuid.UUID(r["role_id"]) if isinstance(r["role_id"], str) else r["role_id"],
                        permission_id=uuid.UUID(r["permission_id"]) if isinstance(r["permission_id"], str) else r["permission_id"]
                    ))
                    total_rows += 1
            else:
                for r in rows:
                    kwargs = {}
                    for attr in inspect(model_or_table).mapper.column_attrs:
                        col_name = attr.columns[0].name
                        val = r.get(col_name)
                        kwargs[attr.key] = parse_val(attr.columns[0].type, val)
                    db.add(model_or_table(**kwargs))
                    total_rows += 1
            
            await db.flush()
            tables_restored += 1
            
        await db.commit()
        return {
            "detail": "Backup restored successfully",
            "tables_restored": tables_restored,
            "total_rows": total_rows
        }
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Database restore failed: {str(e)}")
