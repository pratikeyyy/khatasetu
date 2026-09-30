from pydantic import BaseModel, field_validator
from typing import Optional
from datetime import datetime


class TransactionBase(BaseModel):
    customer_id: int
    amount: float
    transaction_type: str  # CREDIT, PAYMENT, ADJUSTMENT
    date: Optional[datetime] = None
    notes: Optional[str] = None
    payment_mode: Optional[str] = None  # Cash, UPI, Card, Bank Transfer, Cheque, Other

    @field_validator("amount")
    @classmethod
    def validate_amount(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Amount must be greater than zero")
        return round(v, 2)

    @field_validator("transaction_type")
    @classmethod
    def validate_type(cls, v: str) -> str:
        v = v.upper()
        if v not in ("CREDIT", "PAYMENT", "ADJUSTMENT"):
            raise ValueError("Transaction type must be CREDIT, PAYMENT, or ADJUSTMENT")
        return v


class TransactionCreate(TransactionBase):
    pass


class TransactionResponse(TransactionBase):
    id: int
    shop_id: int
    scan_entry_id: Optional[int] = None
    source: str  # MANUAL, AI_SCAN
    customer_name: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class DuplicateCheckResponse(BaseModel):
    is_possible_duplicate: bool
    existing_transaction_id: Optional[int] = None
    existing_amount: Optional[float] = None
    existing_date: Optional[datetime] = None
    message: Optional[str] = None
