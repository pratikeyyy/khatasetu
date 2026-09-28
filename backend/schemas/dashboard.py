from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime


class ChartDataPoint(BaseModel):
    label: str  # Date string, e.g. "15 Sep" or Day name "Mon"
    credit: float
    payment: float
    net: float


class RecentTransactionItem(BaseModel):
    id: int
    customer_id: int
    customer_name: str
    amount: float
    transaction_type: str
    date: datetime
    source: str


class PendingReviewItem(BaseModel):
    entry_id: int
    scan_id: int
    customer_name: str
    amount: float
    confidence_overall: float
    confidence_band: str
    date: Optional[datetime] = None


class DashboardSummaryResponse(BaseModel):
    total_outstanding: float
    today_credit: float
    today_payment: float
    total_customers: int
    total_scans: int
    pending_reviews_count: int
    recent_transactions: List[RecentTransactionItem]
    pending_reviews: List[PendingReviewItem]
    trend_chart: List[ChartDataPoint]
