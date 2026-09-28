import datetime
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from backend.database import Base


class Shop(Base):
    __tablename__ = "shops"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    owner_name = Column(String(255), nullable=False)
    phone = Column(String(50), nullable=False)
    address = Column(Text, nullable=True)
    gstin = Column(String(50), nullable=True)  # Optional GSTIN
    currency = Column(String(10), default="INR")
    currency_symbol = Column(String(5), default="₹")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    # Relationships
    owner = relationship("User", back_populates="shops")
    customers = relationship("Customer", back_populates="shop", cascade="all, delete-orphan")
    transactions = relationship("Transaction", back_populates="shop", cascade="all, delete-orphan")
    scans = relationship("Scan", back_populates="shop", cascade="all, delete-orphan")
    reminders = relationship("Reminder", back_populates="shop", cascade="all, delete-orphan")
