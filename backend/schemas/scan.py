from pydantic import BaseModel, field_validator
from typing import Optional, List
from datetime import datetime
from backend.schemas.customer import FuzzyMatchCandidate


class ConfidenceDetail(BaseModel):
    customer_name: float = 0.0
    amount: float = 0.0
    date: float = 0.0
    transaction_type: float = 0.0
    overall: float = 0.0


class RawExtractedEntry(BaseModel):
    customer_name: Optional[str] = None
    amount: Optional[float] = None
    date: Optional[str] = None
    transaction_type: Optional[str] = "credit"
    raw_text: Optional[str] = None
    confidence: ConfidenceDetail = ConfidenceDetail()


class GeminiExtractionResult(BaseModel):
    entries: List[RawExtractedEntry] = []
    page_notes: Optional[str] = None


class ScanEntryResponse(BaseModel):
    id: int
    scan_id: int
    extracted_customer_name: str
    extracted_amount: float
    extracted_date: Optional[datetime]
    extracted_type: str
    raw_text: Optional[str]
    confidence_customer_name: float
    confidence_amount: float
    confidence_date: float
    confidence_type: float
    confidence_overall: float
    confidence_band: str  # HIGH, NEEDS_REVIEW, MANUAL_VERIFICATION
    is_date_inferred: bool
    status: str  # PENDING, CONFIRMED, EDITED_CONFIRMED, REJECTED
    matched_customer_id: Optional[int] = None
    matched_customer_name: Optional[str] = None
    fuzzy_suggestions: List[FuzzyMatchCandidate] = []
    corrected_customer_name: Optional[str] = None
    corrected_amount: Optional[float] = None
    corrected_date: Optional[datetime] = None
    corrected_type: Optional[str] = None
    confirmed_at: Optional[datetime] = None
    rejection_reason: Optional[str] = None

    class Config:
        from_attributes = True


class ScanResponse(BaseModel):
    id: int
    shop_id: int
    original_image_url: str
    processed_image_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    status: str
    error_message: Optional[str] = None
    total_entries: int
    confirmed_entries: int
    high_confidence_entries: int
    model_name: str
    processing_time_ms: int
    created_at: datetime
    entries: List[ScanEntryResponse] = []

    class Config:
        from_attributes = True


class ScanEntryConfirmRequest(BaseModel):
    customer_id: Optional[int] = None  # Use existing customer, or null to auto-link/create


class ScanEntryEditRequest(BaseModel):
    customer_name: str
    amount: float
    date: Optional[datetime] = None
    transaction_type: str = "CREDIT"
    customer_id: Optional[int] = None

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


class ScanEntryRejectRequest(BaseModel):
    reason: Optional[str] = "Entry rejected by shopkeeper"


class BatchConfirmHighConfidenceRequest(BaseModel):
    scan_id: int
