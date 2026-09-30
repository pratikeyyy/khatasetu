import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from backend.database import Base


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    shop_id = Column(Integer, ForeignKey("shops.id"), nullable=False, index=True)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=False, index=True)
    scan_entry_id = Column(Integer, ForeignKey("scan_entries.id"), nullable=True, index=True)

    amount = Column(Float, nullable=False)
    transaction_type = Column(String(50), nullable=False)  # CREDIT, PAYMENT, ADJUSTMENT
    date = Column(DateTime, default=datetime.datetime.utcnow, nullable=False, index=True)
    notes = Column(Text, nullable=True)
    payment_mode = Column(String(50), nullable=True)  # Cash, UPI, Card, Bank Transfer, Cheque, Other
    source = Column(String(50), default="MANUAL")  # MANUAL, AI_SCAN

    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    # Relationships
    shop = relationship("Shop", back_populates="transactions")
    customer = relationship("Customer", back_populates="transactions")
    scan_entry = relationship("ScanEntry", back_populates="transaction")
    audit_logs = relationship("AuditLog", back_populates="transaction", cascade="all, delete-orphan")
