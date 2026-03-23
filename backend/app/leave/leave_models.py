from sqlalchemy import Column, Integer, String, Date, DateTime, Float, Boolean
from app.database import Base
from datetime import datetime

class Leave(Base):
    __tablename__ = "leaves"

    id = Column(Integer, primary_key=True, index=True)
    faculty_id = Column(String, nullable=False)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    leave_type = Column(String, nullable=False)
    permission_duration = Column(String, nullable=True)   # NEW
    total_days = Column(Float)
    reason = Column(String)
    status = Column(String, default="PENDING")
    applied_at = Column(DateTime, default=datetime.utcnow)
    approved_by = Column(String, nullable=True)
    approved_by_role = Column(String, nullable=True)
    approval_time = Column(DateTime, nullable=True)
    escalated_to = Column(String, nullable=True)
    rejected_reason = Column(String, nullable=True)

class Notification(Base):

    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)

    faculty_id = Column(String, nullable=False)

    message = Column(String)

    created_at = Column(DateTime, default=datetime.utcnow)

    is_read = Column(Boolean, default=False)