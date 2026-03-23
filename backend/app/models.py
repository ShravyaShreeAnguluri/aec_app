from sqlalchemy import Column, Integer, String, DateTime, LargeBinary, Date, Time, Boolean, Float
from .database import Base
from datetime import datetime
from app.holiday.holiday_models import Holiday
from app.docs.docs_models import Subject, Document, Certificate

class Faculty(Base):
    __tablename__ = "faculty"

    id = Column(Integer, primary_key=True, index=True)
    faculty_id = Column(String, unique=True, index=True)
    name = Column(String, nullable=False)
    department = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False, index=True)
    password = Column(String, nullable=False)
    designation = Column(String, nullable=True)
    qualification = Column(String, nullable=True)
    role = Column(String, nullable=False)
    profile_image = Column(LargeBinary, nullable=True)  
    face_embedding = Column(LargeBinary, nullable=True)
    otp = Column(String, nullable=True)
    otp_expiry = Column(DateTime, nullable=True)
    reset_token = Column(String, nullable=True, unique=True)
    reset_token_expiry = Column(DateTime, nullable=True)

class Attendance(Base):
    __tablename__ = "attendance"

    id = Column(Integer, primary_key=True, index=True)
    faculty_id = Column(String, index=True, nullable=False)
    faculty_name = Column(String, nullable=False)
    date = Column(Date, nullable=False, index=True)
    clock_in_time = Column(Time, nullable=True)
    clock_out_time = Column(Time, nullable=True)

    status = Column(String, nullable=False, default="ABSENT")
    working_hours = Column(Float, nullable=False, default=0.0)
    auto_marked = Column(Boolean, nullable=False, default=False)

    remarks = Column(String, nullable=True)
    day_fraction = Column(Float, nullable=False, default=0.0)
    used_permission = Column(Boolean, nullable=False, default=False)

class Department(Base):
    __tablename__ = "departments"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)

from app.leave.leave_models import Leave, Notification
