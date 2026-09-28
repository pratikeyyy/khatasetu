import datetime
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, desc
from typing import List

from backend.database import get_db
from backend.models.customer import Customer
from backend.models.transaction import Transaction
from backend.models.scan import Scan, ScanEntry
from backend.models.shop import Shop
from backend.schemas.dashboard import (
    DashboardSummaryResponse,
    ChartDataPoint,
    RecentTransactionItem,
    PendingReviewItem,
)
from backend.services.auth_service import get_current_shop

router = APIRouter(prefix="/dashboard", tags=["Dashboard & Analytics"])


@router.get("/summary", response_model=DashboardSummaryResponse)
def get_dashboard_summary(
    filter_range: str = Query("7_days", description="today, 7_days, 30_days"),
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    today_start = datetime.datetime.combine(datetime.date.today(), datetime.time.min)
    today_end = datetime.datetime.combine(datetime.date.today(), datetime.time.max)

    # 1. Total Outstanding across all active customers
    total_outstanding_res = db.query(func.sum(Customer.credit_balance)).filter(
        Customer.shop_id == shop.id, Customer.is_active == True
    ).scalar() or 0.0

    # 2. Today's Credit
    today_credit_res = db.query(func.sum(Transaction.amount)).filter(
        Transaction.shop_id == shop.id,
        Transaction.transaction_type == "CREDIT",
        Transaction.date >= today_start,
        Transaction.date <= today_end,
    ).scalar() or 0.0

    # 3. Today's Payment
    today_payment_res = db.query(func.sum(Transaction.amount)).filter(
        Transaction.shop_id == shop.id,
        Transaction.transaction_type == "PAYMENT",
        Transaction.date >= today_start,
        Transaction.date <= today_end,
    ).scalar() or 0.0

    # 4. Total Customers
    total_customers = db.query(Customer).filter(
        Customer.shop_id == shop.id, Customer.is_active == True
    ).count()

    # 5. Total Scans
    total_scans = db.query(Scan).filter(Scan.shop_id == shop.id).count()

    # 6. Pending AI Reviews
    pending_entries_query = db.query(ScanEntry).join(Scan).filter(
        Scan.shop_id == shop.id,
        ScanEntry.status == "PENDING",
    )
    pending_reviews_count = pending_entries_query.count()

    pending_items = []
    for pe in pending_entries_query.order_by(desc(ScanEntry.id)).limit(10).all():
        pending_items.append(
            PendingReviewItem(
                entry_id=pe.id,
                scan_id=pe.scan_id,
                customer_name=pe.extracted_customer_name,
                amount=pe.extracted_amount,
                confidence_overall=pe.confidence_overall,
                confidence_band=pe.confidence_band,
                date=pe.extracted_date,
            )
        )

    # 7. Recent Transactions (last 10)
    recent_txs = (
        db.query(Transaction)
        .filter(Transaction.shop_id == shop.id)
        .order_by(desc(Transaction.date), desc(Transaction.id))
        .limit(10)
        .all()
    )
    recent_items = [
        RecentTransactionItem(
            id=t.id,
            customer_id=t.customer_id,
            customer_name=t.customer.name if t.customer else "Unknown",
            amount=t.amount,
            transaction_type=t.transaction_type,
            date=t.date,
            source=t.source,
        )
        for t in recent_txs
    ]

    # 8. Chart Trend Points
    num_days = 7
    if filter_range == "30_days":
        num_days = 30
    elif filter_range == "today":
        num_days = 1

    chart_points = []
    for i in range(num_days - 1, -1, -1):
        target_date = datetime.date.today() - datetime.timedelta(days=i)
        d_start = datetime.datetime.combine(target_date, datetime.time.min)
        d_end = datetime.datetime.combine(target_date, datetime.time.max)

        day_credit = db.query(func.sum(Transaction.amount)).filter(
            Transaction.shop_id == shop.id,
            Transaction.transaction_type == "CREDIT",
            Transaction.date >= d_start,
            Transaction.date <= d_end,
        ).scalar() or 0.0

        day_payment = db.query(func.sum(Transaction.amount)).filter(
            Transaction.shop_id == shop.id,
            Transaction.transaction_type == "PAYMENT",
            Transaction.date >= d_start,
            Transaction.date <= d_end,
        ).scalar() or 0.0

        label = target_date.strftime("%d %b") if num_days > 1 else "Today"
        chart_points.append(
            ChartDataPoint(
                label=label,
                credit=round(day_credit, 2),
                payment=round(day_payment, 2),
                net=round(day_credit - day_payment, 2),
            )
        )

    return DashboardSummaryResponse(
        total_outstanding=round(total_outstanding_res, 2),
        today_credit=round(today_credit_res, 2),
        today_payment=round(today_payment_res, 2),
        total_customers=total_customers,
        total_scans=total_scans,
        pending_reviews_count=pending_reviews_count,
        recent_transactions=recent_items,
        pending_reviews=pending_items,
        trend_chart=chart_points,
    )
