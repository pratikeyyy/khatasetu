import datetime
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from backend.database import Base


class Customer(Base):
    __tablename__ = "customers"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    shop_id = Column(Integer, ForeignKey("shops.id"), nullable=False, index=True)
    name = Column(String(255), nullable=False, index=True)
    normalized_name = Column(String(255), nullable=False, index=True)  # Lowercase trimmed for search & matching
    phone = Column(String(50), nullable=True, index=True)
    address = Column(Text, nullable=True)
    notes = Column(Text, nullable=True)
    
    # Financial metrics
    credit_balance = Column(Float, default=0.0)  # Positive = customer owes shopkeeper; Negative = advance payment
    total_credit = Column(Float, default=0.0)
    total_payment = Column(Float, default=0.0)
    
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    # Relationships
    shop = relationship("Shop", back_populates="customers")
    transactions = relationship("Transaction", back_populates="customer", cascade="all, delete-orphan", order_by="desc(Transaction.date)")
    reminders = relationship("Reminder", back_populates="customer", cascade="all, delete-orphan")
    scan_entries = relationship("ScanEntry", back_populates="matched_customer")

    def recalculate_balance(self):
        """Authoritative calculation of customer balances from transaction history."""
        net = 0.0
        tot_credit = 0.0
        tot_payment = 0.0
        for tx in self.transactions:
            if tx.transaction_type == "CREDIT":
                tot_credit += tx.amount
                net += tx.amount
            elif tx.transaction_type == "PAYMENT":
                tot_payment += tx.amount
                net -= tx.amount
            elif tx.transaction_type == "ADJUSTMENT":
                # Adjustment can be positive or negative
                net += tx.amount
        self.credit_balance = round(net, 2)
        self.total_credit = round(tot_credit, 2)
        self.total_payment = round(tot_payment, 2)
