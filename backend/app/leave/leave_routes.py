from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.utils.auth_dependency import get_current_user
from .leave_schemas import LeaveApply
from .leave_crud import *
from .leave_crud import auto_escalate_leaves
from .leave_models import Leave
from app.models import Notification, Faculty
from datetime import datetime
from sqlalchemy import or_ , and_

router = APIRouter(prefix="/leave")

@router.post("/apply")
def apply_leave_api(
    data: LeaveApply,
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):

    return apply_leave(db, user["faculty_id"], data)


@router.get("/my-leaves")
def my_leaves(
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):

    return get_faculty_leaves(db, user["faculty_id"])


@router.get("/department-leaves")
def department_leaves(
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):

    if user["role"] != "hod":
        raise HTTPException(status_code=403)

    from app.models import Faculty

    faculty = db.query(Faculty).filter(
        Faculty.faculty_id == user["faculty_id"]
    ).first()
    auto_escalate_leaves(db)

    return get_department_leaves(db, faculty.department)

from app.models import Faculty

@router.get("/hod-leaves")
def hod_leaves(
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):

    if user["role"] != "dean":
        raise HTTPException(status_code=403, detail="Only Dean allowed")

    leaves = db.query(
        Leave,
        Faculty.name,
        Faculty.department,
        Faculty.role

    ).join(
        Faculty,
        Faculty.faculty_id == Leave.faculty_id
    ).filter(
        or_(
            Faculty.role == "hod",
            and_(
                Faculty.role == "faculty",
                Leave.escalated_to == "dean"
            )
        )
    ).all()

    result = []

    for leave, name, department, role in leaves:

        result.append({
            "id": leave.id,
            "faculty_name": name,
            "department": department,
            "role": "HOD" if role == "hod" else "FACULTY ESCALATED",
            "start_date": leave.start_date,
            "end_date": leave.end_date,
            "leave_type": leave.leave_type,
            "reason": leave.reason,
            "status": leave.status,
            "total_days": leave.total_days
        })

    return result

@router.get("/today-department-leaves")
def today_department_leaves(
    db: Session = Depends(get_db),
    user = Depends(get_current_user)
):

    faculty = db.query(Faculty).filter(
        Faculty.faculty_id == user["faculty_id"]
    ).first()

    today = datetime.utcnow().date()

    leaves = db.query(
        Leave,
        Faculty.name,
        Faculty.department
    ).join(
        Faculty,
        Faculty.faculty_id == Leave.faculty_id
    ).filter(
        Faculty.department == faculty.department,
        Leave.start_date <= today,
        Leave.end_date >= today,
        Leave.status == "APPROVED"
    ).all()

    result = []

    for leave, name, department in leaves:

        result.append({
            "id": leave.id,
            "faculty_name": name,
            "department": department,
            "start_date": leave.start_date,
            "end_date": leave.end_date,
            "leave_type": leave.leave_type,
            "reason": leave.reason,
            "status": leave.status,
            "total_days": leave.total_days
            })

    return result

@router.get("/today-hod-leaves")
def today_hod_leaves(
    db: Session = Depends(get_db)
):

    today = datetime.utcnow().date()

    leaves = db.query(
        Leave,
        Faculty.name
    ).join(
        Faculty,
        Faculty.faculty_id == Leave.faculty_id
    ).filter(
        Faculty.role == "hod",
        Leave.start_date <= today,
        Leave.end_date >= today,
        Leave.status == "APPROVED"
    ).all()

    result = []

    for leave, name in leaves:

        result.append({
            "faculty_name": name,
            "leave_type": leave.leave_type
        })

    return result

@router.post("/approve/{leave_id}")
def approve_leave_api(
    leave_id: int,
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):

    if user["role"] not in ["hod", "dean"]:
        raise HTTPException(status_code=403)

    return approve_leave(
        db,
        leave_id,
        user["faculty_id"],
        user["role"]
    )


from pydantic import BaseModel

class RejectRequest(BaseModel):
    reason: str


@router.post("/reject/{leave_id}")
def reject_leave_api(
    leave_id: int,
    data: RejectRequest,
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):

    if user["role"] not in ["hod", "dean"]:
        raise HTTPException(status_code=403)

    return reject_leave(
        db,
        leave_id,
        user["faculty_id"],
        data.reason
    )

@router.post("/cancel/{leave_id}")
def cancel_leave(
    leave_id: int,
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):

    leave = db.query(Leave).filter(
        Leave.id == leave_id,
        Leave.faculty_id == user["faculty_id"]
    ).first()

    if not leave:
        raise HTTPException(status_code=404, detail="Leave not found")

    if leave.status != "PENDING":
        raise HTTPException(
            status_code=400,
            detail="Only pending leave can be cancelled"
        )

    leave.status = "CANCELLED"

    db.add(Notification(
        faculty_id = leave.faculty_id,
        message = "Your leave request was cancelled"
    ))

    db.commit()

    return {"message": "Leave cancelled"}

@router.get("/leave-balance")
def leave_balance(
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):

    from .leave_crud import get_leave_balance

    return get_leave_balance(db, user["faculty_id"])

@router.get("/leave-stats")
def leave_stats(
    db: Session = Depends(get_db)
):

    pending = db.query(Leave).filter(
        Leave.status == "PENDING"
    ).count()

    approved = db.query(Leave).filter(
        Leave.status == "APPROVED"
    ).count()

    emergency = db.query(Leave).filter(
        Leave.leave_type == "Emergency Leave"
    ).count()

    return {
        "pending": pending,
        "approved": approved,
        "emergency": emergency
    }
    
@router.get("/auto-escalate")
def run_escalation(
    db: Session = Depends(get_db)
):

    auto_escalate_leaves(db)

    return {"message": "Escalation executed"}

@router.get("/calendar-leaves")
def calendar_leaves(
    db: Session = Depends(get_db)
):

    from app.models import Faculty

    leaves = db.query(
        Leave,
        Faculty.name
    ).join(
        Faculty,
        Faculty.faculty_id == Leave.faculty_id
    ).filter(
        Leave.status == "APPROVED"
    ).all()

    result = []

    for leave, name in leaves:

        result.append({
            "faculty_name": name,
            "leave_type": leave.leave_type,
            "start_date": leave.start_date,
            "end_date": leave.end_date
        })

    return result

@router.get("/notifications")
def get_notifications(
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):

    notifications = db.query(Notification).filter(
        Notification.faculty_id == user["faculty_id"]
    ).order_by(Notification.created_at.desc()).all()

    return notifications