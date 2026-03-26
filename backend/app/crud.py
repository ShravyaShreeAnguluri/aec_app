from sqlalchemy.orm import Session
from . import models, schemas
from datetime import date, datetime
from .models import Attendance
from sqlalchemy import extract, func

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

    if attendance.clock_in_time is None:
        return "CLOCK_IN_MISSING"

    if clock_out_time <= attendance.clock_in_time:
        return "INVALID_CLOCK_OUT"

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


# =========================================================
# NEW: ATTENDANCE HISTORY
# =========================================================
def get_attendance_history(
    db: Session,
    faculty_id: str,
    start_date: date | None = None,
    end_date: date | None = None
):
    query = db.query(Attendance).filter(Attendance.faculty_id == faculty_id)

    if start_date:
        query = query.filter(Attendance.date >= start_date)

    if end_date:
        query = query.filter(Attendance.date <= end_date)

    return query.order_by(Attendance.date.desc()).all()


# =========================================================
# NEW: ATTENDANCE SUMMARY
# =========================================================
def get_attendance_summary(
    db: Session,
    faculty_id: str,
    start_date: date | None = None,
    end_date: date | None = None
):
    query = db.query(Attendance).filter(Attendance.faculty_id == faculty_id)

    if start_date:
        query = query.filter(Attendance.date >= start_date)

    if end_date:
        query = query.filter(Attendance.date <= end_date)

    records = query.all()

    total_days = len(records)
    present_days = 0.0
    absent_days = 0.0
    leave_days = 0.0
    late_entries = 0
    permission_used_count = 0
    auto_absent_count = 0
    total_working_hours = 0.0

    for row in records:
        total_working_hours += row.working_hours or 0.0

        remarks = (row.remarks or "").strip().lower()

        if "leave" in remarks:
            leave_days += row.day_fraction or 0.0
        elif row.status == "PRESENT":
            present_days += row.day_fraction or 0.0
        elif row.status == "ABSENT":
            absent_days += 1.0

        if row.used_permission:
            permission_used_count += 1

        if row.auto_marked and row.status == "ABSENT":
            auto_absent_count += 1

        if remarks == "present - late entry":
            late_entries += 1

    return {
        "total_records": total_days,
        "present_days": round(present_days, 2),
        "absent_days": round(absent_days, 2),
        "leave_days": round(leave_days, 2),
        "late_entries": late_entries,
        "permissions_used": permission_used_count,
        "auto_absent_count": auto_absent_count,
        "total_working_hours": round(total_working_hours, 2)
    }