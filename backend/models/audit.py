import datetime
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from backend.database import Base


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    actor_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    transaction_id = Column(Integer, ForeignKey("transactions.id"), nullable=True)

    action = Column(String(100), nullable=False, index=True)
    entity_type = Column(String(50), nullable=False)
    entity_id = Column(Integer, nullable=False)

    original_value = Column(Text, nullable=True)  # JSON representation of state before
    new_value = Column(Text, nullable=True)       # JSON representation of state after
    change_summary = Column(Text, nullable=True)

    timestamp = Column(DateTime, default=datetime.datetime.utcnow, index=True)

    # Relationships
    actor = relationship("User", back_populates="audit_logs")
    transaction = relationship("Transaction", back_populates="audit_logs")
