from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class CustomerBase(BaseModel):
    name: str
    phone: Optional[str] = None
    address: Optional[str] = None
    notes: Optional[str] = None


class CustomerCreate(CustomerBase):
    pass


class CustomerUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    notes: Optional[str] = None
    is_active: Optional[bool] = None


class CustomerResponse(CustomerBase):
    id: int
    shop_id: int
    normalized_name: str
    credit_balance: float
    total_credit: float
    total_payment: float
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class FuzzyMatchCandidate(BaseModel):
    customer_id: int
    customer_name: str
    phone: Optional[str] = None
    similarity_score: float  # 0.0 to 1.0
    current_balance: float
    match_reason: str  # e.g. "Similar name to Ramesh Kumar (88% match)"


class CustomerDetailResponse(CustomerResponse):
    transaction_count: int = 0
    scan_count: int = 0
    fuzzy_matches: List[FuzzyMatchCandidate] = []
