from __future__ import annotations

from datetime import date
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.utils.auth_dependency import get_current_user
from . import admin_crud


router = APIRouter(prefix="/admin", tags=["Admin"])


def ensure_admin(current_user: dict):
    if current_user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Only admin allowed")


@router.get("/dashboard-summary")
def admin_dashboard_summary(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ensure_admin(current_user)
    return admin_crud.get_admin_dashboard_summary(db)


@router.get("/faculty-list")
def admin_faculty_list(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ensure_admin(current_user)
    return admin_crud.get_admin_faculty_list(db)


@router.get("/role-summary")
def admin_role_summary(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ensure_admin(current_user)
    return admin_crud.get_admin_role_summary(db)


@router.get("/leave-summary")
def admin_leave_summary(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ensure_admin(current_user)
    return admin_crud.get_admin_leave_summary(db)


@router.get("/department-status")
def admin_department_status(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ensure_admin(current_user)
    return admin_crud.get_department_status_list(db)


@router.get("/reports/attendance-overview")
def admin_attendance_overview(
    start_date: date | None = None,
    end_date: date | None = None,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ensure_admin(current_user)
    return admin_crud.get_admin_attendance_overview(
        db=db,
        start_date=start_date,
        end_date=end_date,
    )