from sqlalchemy.orm import Session
from . import models, schemas
from datetime import date, datetime
from .models import Attendance
from sqlalchemy import extract

def create_faculty(db: Session, faculty: schemas.FacultyCreate, face_embedding: bytes):
    db_faculty = models.Faculty(
        faculty_id=faculty.faculty_id,
        name=faculty.name,
        department=faculty.department,
        email=faculty.email,
        password=faculty.password,
        face_embedding=face_embedding,
        role=faculty.role,
        profile_image=faculty.profile_image
    )
    db.add(db_faculty)
    db.commit()
    db.refresh(db_faculty)
    return db_faculty

def get_faculty_by_email(db: Session, email: str):
    return db.query(models.Faculty).filter(models.Faculty.email == email).first()

def get_today_attendance(db: Session, faculty_id: str):
    return db.query(Attendance).filter(
        Attendance.faculty_id == faculty_id,
        Attendance.date == date.today()
    ).first()

def create_attendance(
    db: Session, 
    faculty_id: str, 
    faculty_name: str, 
    clock_in_time,
    status: str,
    remarks: str,
    day_fraction: float,
    used_permission: bool = False
    ):
    attendance = Attendance(
        faculty_id=faculty_id,
        faculty_name=faculty_name,
        date=date.today(),
        clock_in_time=clock_in_time,
        status=status,
        remarks=remarks,
        day_fraction=day_fraction,
        used_permission=used_permission,
        working_hours=0.0,
        auto_marked=False
    )
    db.add(attendance)
    db.commit()
    db.refresh(attendance)
    return attendance

def get_monthly_permission_count(db: Session, faculty_id: str):
    now = datetime.now()
    return db.query(Attendance).filter(
        Attendance.faculty_id == faculty_id,
        Attendance.used_permission == True,
        extract("month", Attendance.date) == now.month,
        extract("year", Attendance.date) == now.year
    ).count()

def clock_out_attendance(db: Session, faculty_id: str, clock_out_time):
    attendance = db.query(Attendance).filter(
        Attendance.faculty_id == faculty_id,
        Attendance.date == date.today()
    ).first()

    if not attendance:
        return None

    if attendance.status == "ABSENT":
        return "ABSENT_RECORD"

    if attendance.clock_out_time is not None:
        return "ALREADY_CLOCKED_OUT"

    if clock_out_time <= attendance.clock_in_time:
        return "INVALID_CLOCK_OUT"

    if attendance.clock_in_time is None:
        return "CLOCK_IN_MISSING"

    attendance.clock_out_time = clock_out_time

    dt_in = datetime.combine(date.today(), attendance.clock_in_time)
    dt_out = datetime.combine(date.today(), clock_out_time)

    total_seconds = (dt_out - dt_in).total_seconds()
    attendance.working_hours = round(max(total_seconds, 0) / 3600, 2)

    db.commit()
    db.refresh(attendance)
    return attendance

def auto_mark_absent_for_faculty(db: Session, faculty_id: str, faculty_name: str):
    attendance = Attendance(
        faculty_id=faculty_id,
        faculty_name=faculty_name,
        date=date.today(),
        clock_in_time=None,
        clock_out_time=None,
        status="ABSENT",
        remarks="Absent",
        day_fraction=0.0,
        used_permission=False,
        working_hours=0.0,
        auto_marked=True
    )
    db.add(attendance)
    db.commit()
    db.refresh(attendance)
    return attendance