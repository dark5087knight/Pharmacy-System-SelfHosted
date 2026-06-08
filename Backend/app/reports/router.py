from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from typing import List
from datetime import datetime, timedelta, timezone, date
import uuid

from app.shared.database import get_db
from app.dependencies import get_current_user, require_permission
from app.models import Staff, Medicine, MedicineCategory, Sale, PurchaseOrder, Activity
from app.reports.schemas import DashboardResponse

router = APIRouter(tags=["Reports & Dashboard"])

@router.get("/dashboard", response_model=DashboardResponse)
async def get_dashboard_data(
    db: AsyncSession = Depends(get_db), 
    current_user: Staff = Depends(require_permission("view_reports"))
):
    # 1. Fetch all medicines for stats and category breakdown
    med_stmt = select(Medicine).options(selectinload(Medicine.category))
    med_res = await db.execute(med_stmt)
    medicines = med_res.scalars().all()

    # 2. Fetch completed sales for revenue stats, series, and top sold
    sales_stmt = select(Sale).filter(Sale.status == "completed").options(selectinload(Sale.items))
    sales_res = await db.execute(sales_stmt)
    sales = sales_res.scalars().all()

    # 3. Fetch purchase orders for pending count
    po_stmt = select(PurchaseOrder).filter(PurchaseOrder.status.in_(["draft", "sent", "pending", "partial"]))
    po_res = await db.execute(po_stmt)
    purchase_orders = po_res.scalars().all()

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

    # --- Calculations ---
    now_date = datetime.now(timezone.utc).date()
    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    
    today_revenue = sum(float(s.total) for s in sales if s.created_at >= today_start)
    month_revenue = sum(float(s.total) for s in sales)
    profit = round(month_revenue * 0.28, 2)

    expiring_soon = 0
    expired = 0
    out_of_stock = 0
    low_stock = 0

    for m in medicines:
        if m.quantity <= 0:
            out_of_stock += 1
        elif m.quantity <= m.low_stock_threshold:
            low_stock += 1
        
        if m.expiry_date:
            # expiry_date is a datetime.date object
            diff_days = (m.expiry_date - now_date).days
            if diff_days < 0:
                expired += 1
            elif diff_days <= 60:
                expiring_soon += 1

    stats = {
        "today_revenue": today_revenue,
        "month_revenue": month_revenue,
        "profit": profit,
        "expiring_soon": expiring_soon,
        "expired": expired,
        "out_of_stock": out_of_stock,
        "low_stock": low_stock
    }

    # Revenue timeline graph dataset (last 30 days)
    revenue_by_day = {}
    for s in sales:
        day_str = s.created_at.strftime("%Y-%m-%d")
        revenue_by_day[day_str] = revenue_by_day.get(day_str, 0.0) + float(s.total)

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

    # Category breakdown mapping
    cat_map = {}
    for m in medicines:
        cat_name = m.category.name if m.category else "Analgesic"
        cat_map[cat_name] = cat_map.get(cat_name, 0.0) + m.quantity * float(m.selling_price)
        
    category_breakdown = [{"name": k, "value": round(v)} for k, v in cat_map.items()]

    # Top/least sold computations
    sold_map = {}
    for s in sales:
        for it in s.items:
            med_id_str = str(it.medicine_id)
            if med_id_str not in sold_map:
                sold_map[med_id_str] = {"name": it.name, "qty": 0, "revenue": 0.0}
            sold_map[med_id_str]["qty"] += it.quantity
            sold_map[med_id_str]["revenue"] += float(it.unit_price) * it.quantity
    
    top_sold_list = list(sold_map.values())
    top_sold_list.sort(key=lambda x: x["qty"], reverse=True)
    top_sold = top_sold_list[:6]
    least_sold = list(reversed(top_sold_list))[:5]

    return {
        "stats": stats,
        "revenue_series": revenue_series,
        "category_breakdown": category_breakdown,
        "top_sold": top_sold,
        "least_sold": least_sold,
        "recent_activity": recent_activity,
        "pending_orders": len(purchase_orders)
    }
