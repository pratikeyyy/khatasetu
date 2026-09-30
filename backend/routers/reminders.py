from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import List

from backend.database import get_db
from backend.models.customer import Customer
from backend.models.reminder import Reminder
from backend.models.shop import Shop
from backend.schemas.reminder import (
    WhatsAppReminderRequest,
    WhatsAppReminderResponse,
    ReminderHistoryItem,
)
from backend.services.auth_service import get_current_shop
from backend.services.reminder_service import ReminderService

router = APIRouter(prefix="/reminders", tags=["Reminders"])


@router.post("/whatsapp", response_model=WhatsAppReminderResponse)
def generate_whatsapp_reminder(
    data: WhatsAppReminderRequest,
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    customer = db.query(Customer).filter(
        Customer.id == data.customer_id,
        Customer.shop_id == shop.id,
    ).first()

    if not customer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer not found.")

    if customer.credit_balance <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{customer.name} has no outstanding balance (Balance: ₹{customer.credit_balance:.2f}).",
        )

    link_data = ReminderService.generate_whatsapp_deep_link(
        phone=customer.phone or "",
        customer_name=customer.name,
        amount=customer.credit_balance,
        shop_name=shop.name,
        language=data.language,
        custom_note=data.custom_note,
        upi_id=shop.upi_id,
    )

    # Save to Reminder history
    reminder = Reminder(
        shop_id=shop.id,
        customer_id=customer.id,
        outstanding_amount=customer.credit_balance,
        phone=link_data["phone"],
        message_body=link_data["message_text"],
        deep_link=link_data["whatsapp_url"],
        status="GENERATED",
    )
    db.add(reminder)
    db.commit()
    db.refresh(reminder)

    return WhatsAppReminderResponse(
        customer_id=customer.id,
        customer_name=customer.name,
        phone=link_data["phone"],
        outstanding_amount=customer.credit_balance,
        message_text=link_data["message_text"],
        whatsapp_url=link_data["whatsapp_url"],
    )


@router.get("/history", response_model=List[ReminderHistoryItem])
def get_reminder_history(
    customer_id: int = Query(None),
    limit: int = Query(50, le=200),
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    query = db.query(Reminder).filter(Reminder.shop_id == shop.id)
    if customer_id:
        query = query.filter(Reminder.customer_id == customer_id)

    reminders = query.order_by(desc(Reminder.created_at)).limit(limit).all()

    items = []
    for r in reminders:
        items.append(
            ReminderHistoryItem(
                id=r.id,
                customer_id=r.customer_id,
                customer_name=r.customer.name if r.customer else "Unknown",
                phone=r.phone,
                outstanding_amount=r.outstanding_amount,
                message_body=r.message_body,
                status=r.status,
                created_at=r.created_at,
            )
        )
    return items
