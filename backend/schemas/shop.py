from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class ShopBase(BaseModel):
    name: str
    owner_name: str
    phone: str
    address: Optional[str] = None
    gstin: Optional[str] = None
    currency: str = "INR"
    currency_symbol: str = "₹"


class ShopCreate(ShopBase):
    pass


class ShopUpdate(BaseModel):
    name: Optional[str] = None
    owner_name: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    gstin: Optional[str] = None


class ShopResponse(ShopBase):
    id: int
    owner_id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
