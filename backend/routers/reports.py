import datetime
from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session
from sqlalchemy import desc

from backend.database import get_db
from backend.models.transaction import Transaction
from backend.models.customer import Customer
from backend.models.shop import Shop
from backend.services.auth_service import get_current_shop
from backend.services.report_service import ReportService

router = APIRouter(prefix="/reports", tags=["Reports & Exports"])


@router.get("/transactions/csv")
def export_transactions_csv(
    start_date: datetime.date = Query(None),
    end_date: datetime.date = Query(None),
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    query = db.query(Transaction).filter(Transaction.shop_id == shop.id)
    if start_date:
        query = query.filter(Transaction.date >= datetime.datetime.combine(start_date, datetime.time.min))
    if end_date:
        query = query.filter(Transaction.date <= datetime.datetime.combine(end_date, datetime.time.max))

    txs = query.order_by(desc(Transaction.date)).all()
    csv_content = ReportService.generate_transactions_csv(txs)

    filename = f"khatasetu_transactions_{datetime.date.today().strftime('%Y%m%d')}.csv"
    return Response(
        content=csv_content,
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


@router.get("/customers/csv")
def export_customers_csv(
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    customers = db.query(Customer).filter(
        Customer.shop_id == shop.id,
        Customer.is_active == True,
    ).order_by(Customer.name).all()

    csv_content = ReportService.generate_customers_csv(customers)
    filename = f"khatasetu_customers_{datetime.date.today().strftime('%Y%m%d')}.csv"
    return Response(
        content=csv_content,
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )
