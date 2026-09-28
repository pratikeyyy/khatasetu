import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from backend.database import Base


class Reminder(Base):
    __tablename__ = "reminders"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    shop_id = Column(Integer, ForeignKey("shops.id"), nullable=False, index=True)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=False, index=True)

    outstanding_amount = Column(Float, nullable=False)
    phone = Column(String(50), nullable=False)
    message_body = Column(Text, nullable=False)
    deep_link = Column(Text, nullable=False)
    status = Column(String(50), default="GENERATED")  # GENERATED, OPENED_IN_WA, SENT

    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    # Relationships
    shop = relationship("Shop", back_populates="reminders")
    customer = relationship("Customer", back_populates="reminders")
