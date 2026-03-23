from sqlalchemy import Column, Integer, String, Date, DateTime, Boolean, Text
from datetime import datetime
from app.database import Base


class Holiday(Base):
    __tablename__ = "holidays"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(150), nullable=False)
    start_date = Column(Date, nullable=False, index=True)
    end_date = Column(Date, nullable=False, index=True)
    description = Column(Text, nullable=True)
    holiday_type = Column(String(20), nullable=False)  # PUBLIC / CUSTOM
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)