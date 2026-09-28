from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class WhatsAppReminderRequest(BaseModel):
    customer_id: int
    custom_note: Optional[str] = None
    language: str = "hinglish"  # hinglish, hindi, english


class WhatsAppReminderResponse(BaseModel):
    customer_id: int
    customer_name: str
    phone: str
    outstanding_amount: float
    message_text: str
    whatsapp_url: str  # Direct https://wa.me/91XXXXXXXXXX?text=...


class ReminderHistoryItem(BaseModel):
    id: int
    customer_id: int
    customer_name: str
    phone: str
    outstanding_amount: float
    message_body: str
    status: str
    created_at: datetime

    class Config:
        from_attributes = True
