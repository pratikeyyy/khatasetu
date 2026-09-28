import datetime
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from backend.database import Base


class Scan(Base):
    __tablename__ = "scans"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    shop_id = Column(Integer, ForeignKey("shops.id"), nullable=False, index=True)

    original_image_path = Column(String(500), nullable=False)
    processed_image_path = Column(String(500), nullable=True)
    thumbnail_path = Column(String(500), nullable=True)

    # Status: UPLOADED, PROCESSING, REVIEW_NEEDED, CONFIRMED, PARTIAL_CONFIRMED, FAILED
    status = Column(String(50), default="UPLOADED", index=True)
    error_message = Column(Text, nullable=True)

    total_entries = Column(Integer, default=0)
    confirmed_entries = Column(Integer, default=0)
    high_confidence_entries = Column(Integer, default=0)

    model_name = Column(String(100), default="gemini-1.5-flash")
    raw_ai_response = Column(Text, nullable=True)
    processing_time_ms = Column(Integer, default=0)

    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    # Relationships
    shop = relationship("Shop", back_populates="scans")
    entries = relationship("ScanEntry", back_populates="scan", cascade="all, delete-orphan")


class ScanEntry(Base):
    __tablename__ = "scan_entries"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    scan_id = Column(Integer, ForeignKey("scans.id"), nullable=False, index=True)
    matched_customer_id = Column(Integer, ForeignKey("customers.id"), nullable=True, index=True)

    # Extracted by AI
    extracted_customer_name = Column(String(255), nullable=False)
    extracted_amount = Column(Float, nullable=False)
    extracted_date = Column(DateTime, nullable=True)
    extracted_type = Column(String(50), default="CREDIT")  # CREDIT, PAYMENT, ADJUSTMENT, UNKNOWN
    raw_text = Column(Text, nullable=True)

    # Field-level & Overall Confidence scores (0.0 to 1.0)
    confidence_customer_name = Column(Float, default=0.0)
    confidence_amount = Column(Float, default=0.0)
    confidence_date = Column(Float, default=0.0)
    confidence_type = Column(Float, default=0.0)
    confidence_overall = Column(Float, default=0.0)

    # Confidence Band: HIGH (>=0.95), NEEDS_REVIEW (0.80-0.94), MANUAL_VERIFICATION (<0.80)
    confidence_band = Column(String(50), default="NEEDS_REVIEW")
    is_date_inferred = Column(Boolean, default=False)

    # Status: PENDING, CONFIRMED, EDITED_CONFIRMED, REJECTED
    status = Column(String(50), default="PENDING", index=True)

    # Corrections (audit trail of human intervention)
    corrected_customer_name = Column(String(255), nullable=True)
    corrected_amount = Column(Float, nullable=True)
    corrected_date = Column(DateTime, nullable=True)
    corrected_type = Column(String(50), nullable=True)

    confirmed_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    confirmed_at = Column(DateTime, nullable=True)
    rejection_reason = Column(Text, nullable=True)

    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    # Relationships
    scan = relationship("Scan", back_populates="entries")
    matched_customer = relationship("Customer", back_populates="scan_entries")
    transaction = relationship("Transaction", back_populates="scan_entry", uselist=False)
