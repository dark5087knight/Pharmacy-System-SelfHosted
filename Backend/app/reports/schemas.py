from pydantic import BaseModel, ConfigDict
from typing import List
from app.audit.schemas import ActivityEventResponse

def to_camel(string: str) -> str:
    parts = string.split('_')
    return parts[0] + ''.join(word.capitalize() for word in parts[1:])

class CamelModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True
    )

class DashboardStatsSchema(CamelModel):
    today_revenue: float
    month_revenue: float
    profit: float
    expiring_soon: int
    expired: int
    out_of_stock: int
    low_stock: int

class DashboardResponse(CamelModel):
    stats: DashboardStatsSchema
    revenue_series: List[dict]
    category_breakdown: List[dict]
    top_sold: List[dict]
    least_sold: List[dict]
    recent_activity: List[ActivityEventResponse]
    pending_orders: int
