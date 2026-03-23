from datetime import datetime,timedelta
from sqlalchemy.orm import Session
from .leave_models import Leave
from app.models import Faculty
from fastapi import HTTPException
from .leave_models import Notification
from app.holiday.holiday_service import validate_leave_range_has_working_day

def calculate_days(start_date, end_date):

    return (end_date - start_date).days + 1


def apply_leave(db: Session, faculty_id: str, data):

    if data.start_date > data.end_date:
        raise HTTPException(status_code=400, detail="Start date cannot be after end date.")

    # ---------- CHECK DATE CONFLICT ----------
    conflict = db.query(Leave).filter(
        Leave.faculty_id == faculty_id,
        Leave.status.notin_(["REJECTED", "CANCELLED"]),
        Leave.start_date <= data.end_date,
        Leave.end_date >= data.start_date
    ).first()

    if conflict:
        raise HTTPException(
            status_code=400,
            detail="You already have leave applied for these dates"
        )

    if data.leave_type == "Permission":

        if data.permission_duration in ["Half Day Morning", "Half Day Afternoon"]:
            total_days = 0.5
        else:
            total_days = 1

    else:
        summary = validate_leave_range_has_working_day(db, data.start_date, data.end_date)
        total_days = summary["total_working_days"]

    leave = Leave(
    faculty_id=faculty_id,
    start_date=data.start_date,
    end_date=data.end_date,
    leave_type=data.leave_type,
    permission_duration=data.permission_duration,
    reason=data.reason,
    total_days=total_days
    )

    db.add(leave)
    db.commit()
    db.refresh(leave)

    return {
        "message": "Leave applied successfully",
        "total_days": total_days
    }


def get_faculty_leaves(db: Session, faculty_id: str):

    return db.query(Leave).filter(
        Leave.faculty_id == faculty_id
    ).order_by(
        Leave.applied_at.desc()
    ).all()


def approve_leave(db: Session, leave_id, approver_id, role):

    leave = db.query(Leave).filter(
        Leave.id == leave_id
    ).first()

    leave.status = "APPROVED"

    leave.approved_by = approver_id
    leave.approved_by_role = role
    leave.approval_time = datetime.utcnow()

    db.add(Notification(
        faculty_id = leave.faculty_id,
        message = f"Your leave request was approved by {role.upper()}"
    ))

    db.commit()

    return {"message": "Leave approved"}


def reject_leave(db: Session, leave_id, approver_id, reason):

    leave = db.query(Leave).filter(
        Leave.id == leave_id
    ).first()

    leave.status = "REJECTED"
    leave.rejected_reason = reason

    db.add(Notification(
        faculty_id = leave.faculty_id,
        message = "Your leave request was rejected"
    ))
    db.commit()

    return {"message": "Leave rejected"}


def get_department_leaves(db: Session, department):

    leaves = db.query(
        Leave,
        Faculty.name,
        Faculty.department
    ).join(
        Faculty,
        Faculty.faculty_id == Leave.faculty_id
    ).filter(
        Faculty.department == department,
        Faculty.role == "faculty"
    ).all()

    result = []

    for leave, name,dept  in leaves:

        result.append({
            "id": leave.id,
            "faculty_name": name,
            "department": dept,
            "role": "FACULTY",
            "start_date": leave.start_date,
            "end_date": leave.end_date,
            "leave_type": leave.leave_type,
            "reason": leave.reason,
            "status": leave.status,
            "total_days": leave.total_days
        })

    return result

from datetime import date
from sqlalchemy import extract
from .leave_models import Leave

def get_leave_balance(db, faculty_id):

    current_year = date.today().year

    used_leaves = db.query(Leave).filter(
        Leave.faculty_id == faculty_id,
        Leave.status == "APPROVED",
        extract('year', Leave.start_date) == current_year
    ).all()

    total_used = sum(l.total_days or 0 for l in used_leaves)

    total_allowed = 12
    remaining = max(total_allowed - total_used, 0)

    return {
        "total_allowed": total_allowed,
        "used": total_used,
        "remaining": remaining
    }

def auto_escalate_leaves(db):

    leaves = db.query(Leave, Faculty.role)\
    .join(Faculty,Faculty.faculty_id == Leave.faculty_id)\
    .filter(
        Leave.status == "PENDING",
        Faculty.role == "faculty"
    ).all()

    now = datetime.utcnow()

    for leave, role in leaves:

        if leave.applied_at and now - leave.applied_at > timedelta(hours=12):

            leave.escalated_to = "dean"

    db.commit()