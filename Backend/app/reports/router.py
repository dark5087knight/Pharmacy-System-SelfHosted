from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import func, Date, cast
from typing import List
from datetime import datetime, timedelta, timezone, date
import uuid

from app.shared.database import get_db
from app.dependencies import get_current_user, require_permission
from app.models import Staff, Medicine, MedicineCategory, Sale, SaleItem, PurchaseOrder, Activity
from app.reports.schemas import DashboardResponse

router = APIRouter(tags=["Reports & Dashboard"])

@router.get("/dashboard", response_model=DashboardResponse)
async def get_dashboard_data(
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(require_permission("view_reports"))
):
    # 1. Calculate medicine statistics in database
    now_date = datetime.now(timezone.utc).date()
    
    out_of_stock_stmt = select(func.count()).select_from(Medicine).filter(Medicine.quantity <= 0)
    low_stock_stmt = (
        select(func.count())
        .select_from(Medicine)
        .filter(Medicine.quantity > 0, Medicine.quantity <= Medicine.low_stock_threshold)
    )
    expired_stmt = select(func.count()).select_from(Medicine).filter(Medicine.expiry_date < now_date)
    expiring_soon_stmt = (
        select(func.count())
        .select_from(Medicine)
        .filter(Medicine.expiry_date >= now_date, Medicine.expiry_date <= now_date + timedelta(days=60))
    )
    
    out_of_stock = (await db.execute(out_of_stock_stmt)).scalar() or 0
    low_stock = (await db.execute(low_stock_stmt)).scalar() or 0
    expired = (await db.execute(expired_stmt)).scalar() or 0
    expiring_soon = (await db.execute(expiring_soon_stmt)).scalar() or 0

    # 2. Fetch sales stats (revenue)
    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    
    today_rev_stmt = select(func.sum(Sale.total)).filter(Sale.status == "completed", Sale.created_at >= today_start)
    month_rev_stmt = select(func.sum(Sale.total)).filter(Sale.status == "completed")
    
    today_revenue = float((await db.execute(today_rev_stmt)).scalar() or 0.0)
    month_revenue = float((await db.execute(month_rev_stmt)).scalar() or 0.0)
    profit = round(month_revenue * 0.28, 2)

    stats = {
        "today_revenue": today_revenue,
        "month_revenue": month_revenue,
        "profit": profit,
        "expiring_soon": expiring_soon,
        "expired": expired,
        "out_of_stock": out_of_stock,
        "low_stock": low_stock
    }

    # 3. Fetch purchase orders count
    po_stmt = select(func.count()).select_from(PurchaseOrder).filter(PurchaseOrder.status.in_(["draft", "sent", "pending", "partial"]))
    pending_orders = (await db.execute(po_stmt)).scalar() or 0

    # 4. Fetch recent activities (max 10)
    act_stmt = (
        select(Activity, Staff.name)
        .outerjoin(Staff, Activity.actor_id == Staff.id)
        .order_by(Activity.created_at.desc())
        .limit(10)
    )
    act_res = await db.execute(act_stmt)
    recent_activity = []
    for act, actor_name in act_res.all():
        recent_activity.append({
            "id": str(act.id),
            "type": act.type,
            "message": act.message,
            "actor": actor_name or "System",
            "at": act.created_at.isoformat(),
            "severity": act.severity
        })

    # 5. Revenue timeline graph dataset (last 30 days)
    thirty_days_ago = datetime.now(timezone.utc) - timedelta(days=30)
    timeline_stmt = (
        select(
            cast(Sale.created_at, Date).label('day'),
            func.sum(Sale.total)
        )
        .filter(Sale.status == "completed", Sale.created_at >= thirty_days_ago)
        .group_by(cast(Sale.created_at, Date))
    )
    timeline_res = await db.execute(timeline_stmt)
    revenue_by_day = {day.strftime("%Y-%m-%d"): float(val) for day, val in timeline_res.all() if day}

    revenue_series = []
    for i in range(30):
        d = datetime.now(timezone.utc) - timedelta(days=(29 - i))
        d_str = d.strftime("%Y-%m-%d")
        rev = revenue_by_day.get(d_str, 0.0)
        revenue_series.append({
            "day": d.strftime("%b %d"),
            "revenue": round(rev, 2),
            "profit": round(rev * 0.28, 2)
        })

    # 6. Category breakdown mapping
    cat_stmt = (
        select(func.coalesce(MedicineCategory.name, 'Analgesic'), func.sum(Medicine.quantity * Medicine.selling_price))
        .outerjoin(MedicineCategory, Medicine.category_id == MedicineCategory.id)
        .group_by(func.coalesce(MedicineCategory.name, 'Analgesic'))
    )
    cat_res = await db.execute(cat_stmt)
    category_breakdown = [{"name": name, "value": round(float(val or 0))} for name, val in cat_res.all()]

    # 7. Top/least sold computations
    top_sold_stmt = (
        select(
            SaleItem.name,
            func.sum(SaleItem.quantity).label('qty'),
            func.sum(SaleItem.unit_price * SaleItem.quantity).label('revenue')
        )
        .join(Sale, SaleItem.sale_id == Sale.id)
        .filter(Sale.status == "completed")
        .group_by(SaleItem.name)
        .order_by(func.sum(SaleItem.quantity).desc())
    )
    top_sold_res = await db.execute(top_sold_stmt.limit(6))
    top_sold = [{"name": name, "qty": int(qty), "revenue": float(rev)} for name, qty, rev in top_sold_res.all()]
    
    least_sold_stmt = (
        select(
            SaleItem.name,
            func.sum(SaleItem.quantity).label('qty'),
            func.sum(SaleItem.unit_price * SaleItem.quantity).label('revenue')
        )
        .join(Sale, SaleItem.sale_id == Sale.id)
        .filter(Sale.status == "completed")
        .group_by(SaleItem.name)
        .order_by(func.sum(SaleItem.quantity).asc())
    )
    least_sold_res = await db.execute(least_sold_stmt.limit(5))
    least_sold = [{"name": name, "qty": int(qty), "revenue": float(rev)} for name, qty, rev in least_sold_res.all()]

    return {
        "stats": stats,
        "revenue_series": revenue_series,
        "category_breakdown": category_breakdown,
        "top_sold": top_sold,
        "least_sold": least_sold,
        "recent_activity": recent_activity,
        "pending_orders": pending_orders
    }
