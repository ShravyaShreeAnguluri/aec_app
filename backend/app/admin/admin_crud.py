from __future__ import annotations

from datetime import date
from sqlalchemy.orm import Session

from app.models import Faculty, Attendance, Department
from app.leave.leave_models import Leave


ACTIVE_STAFF_ROLES = {"faculty", "hod", "dean", "operator"}


def _safe_str(value) -> str:
    return (value or "").strip()


def _get_department_names(db: Session) -> list[str]:
    db_departments = db.query(Department).order_by(Department.name.asc()).all()
    names = [_safe_str(d.name) for d in db_departments if _safe_str(d.name)]

    if names:
        return names

    faculty_departments = (
        db.query(Faculty.department)
        .distinct()
        .order_by(Faculty.department.asc())
        .all()
    )
    return [_safe_str(row[0]) for row in faculty_departments if _safe_str(row[0])]


def _faculty_to_dict(user: Faculty) -> dict:
    return {
        "faculty_id": user.faculty_id,
        "name": user.name,
        "email": user.email,
        "department": user.department,
        "role": user.role,
        "designation": user.designation,
        "qualification": user.qualification,
    }


def _department_people_map(users: list[Faculty]) -> dict[str, list[Faculty]]:
    grouped: dict[str, list[Faculty]] = {}
    for user in users:
        dept = _safe_str(user.department) or "Unknown"
        grouped.setdefault(dept, []).append(user)
    return grouped


def get_admin_faculty_list(db: Session) -> list[dict]:
    users = (
        db.query(Faculty)
        .order_by(Faculty.department.asc(), Faculty.name.asc())
        .all()
    )
    return [_faculty_to_dict(user) for user in users]


def get_admin_role_summary(db: Session) -> dict:
    users = db.query(Faculty).all()

    summary = {
        "total_users": 0,
        "faculty": 0,
        "hod": 0,
        "dean": 0,
        "operator": 0,
        "admin": 0,
    }

    for user in users:
        role = _safe_str(user.role).lower()
        summary["total_users"] += 1

        if role in summary:
            summary[role] += 1

    summary["active_staff"] = (
        summary["faculty"] + summary["hod"] + summary["dean"] + summary["operator"]
    )

    return summary


def get_admin_leave_summary(db: Session, target_date: date | None = None) -> dict:
    """
    Real-life admin view:
    admin mainly monitors who is currently on leave,
    not approved / rejected / pending breakdown cards.
    """
    target_date = target_date or date.today()

    active_today = (
        db.query(Leave)
        .filter(
            Leave.status == "APPROVED",
            Leave.start_date <= target_date,
            Leave.end_date >= target_date,
        )
        .all()
    )

    all_faculty = db.query(Faculty).all()
    faculty_map = {user.faculty_id: user for user in all_faculty}

    departments_with_leave = set()
    for leave in active_today:
        owner = faculty_map.get(leave.faculty_id)
        if owner and _safe_str(owner.department):
            departments_with_leave.add(_safe_str(owner.department))

    return {
        "date": str(target_date),
        "on_leave_today": len(active_today),
        "departments_with_leave": len(departments_with_leave),
    }


def get_admin_dashboard_summary(db: Session, target_date: date | None = None) -> dict:
    target_date = target_date or date.today()

    role_summary = get_admin_role_summary(db)
    total_departments = len(_get_department_names(db))
    active_staff = role_summary["active_staff"]

    all_staff = (
        db.query(Faculty)
        .order_by(Faculty.department.asc(), Faculty.name.asc())
        .all()
    )
    dept_map = _department_people_map(all_staff)

    attendance_rows = db.query(Attendance).filter(Attendance.date == target_date).all()

    present_today = sum(
        1 for row in attendance_rows if (row.status or "").upper() == "PRESENT"
    )

    absent_today = 0
    for row in attendance_rows:
        status = (row.status or "").upper()
        remarks = (row.remarks or "").strip().lower()
        if status == "ABSENT" and "leave" not in remarks:
            absent_today += 1

    leave_today_count = (
        db.query(Leave)
        .filter(
            Leave.status == "APPROVED",
            Leave.start_date <= target_date,
            Leave.end_date >= target_date,
        )
        .count()
    )

    departments_without_hod = 0
    departments_without_operator = 0
    departments_needing_attention = 0

    for dept_name in _get_department_names(db):
        members = dept_map.get(dept_name, [])
        has_hod = any(_safe_str(u.role).lower() == "hod" for u in members)
        has_operator = any(_safe_str(u.role).lower() == "operator" for u in members)

        if not has_hod:
            departments_without_hod += 1
        if not has_operator:
            departments_without_operator += 1
        if not has_hod or not has_operator:
            departments_needing_attention += 1

    attendance_percent = (
        round((present_today / active_staff) * 100, 1) if active_staff else 0.0
    )

    return {
        "date": str(target_date),
        "total_users": role_summary["total_users"],
        "total_faculty": active_staff,
        "total_departments": total_departments,
        "faculty_count": role_summary["faculty"],
        "hod_count": role_summary["hod"],
        "dean_count": role_summary["dean"],
        "operator_count": role_summary["operator"],
        "admin_count": role_summary["admin"],
        "present_today": present_today,
        "absent_today": absent_today,
        "on_leave_today": leave_today_count,
        "today_attendance_percent": attendance_percent,
        "dean_assigned": 1 if role_summary["dean"] > 0 else 0,
        "departments_without_hod": departments_without_hod,
        "departments_without_operator": departments_without_operator,
        "departments_needing_attention": departments_needing_attention,
    }


def get_department_status_list(db: Session, target_date: date | None = None) -> list[dict]:
    target_date = target_date or date.today()
    department_names = _get_department_names(db)

    all_faculty = db.query(Faculty).all()
    all_attendance_today = (
        db.query(Attendance)
        .filter(Attendance.date == target_date)
        .all()
    )
    all_active_leaves_today = (
        db.query(Leave)
        .filter(
            Leave.status == "APPROVED",
            Leave.start_date <= target_date,
            Leave.end_date >= target_date,
        )
        .all()
    )

    faculty_map = {user.faculty_id: user for user in all_faculty}

    results: list[dict] = []

    for dept_name in department_names:
        dept_users = [
            user
            for user in all_faculty
            if _safe_str(user.department) == dept_name
            and _safe_str(user.role).lower() in ACTIVE_STAFF_ROLES
        ]

        faculty_ids = {user.faculty_id for user in dept_users}

        hod_user = next(
            (u for u in dept_users if _safe_str(u.role).lower() == "hod"),
            None,
        )
        operator_user = next(
            (u for u in dept_users if _safe_str(u.role).lower() == "operator"),
            None,
        )

        today_attendance = [
            row for row in all_attendance_today if row.faculty_id in faculty_ids
        ]

        present_count = sum(
            1 for row in today_attendance if (row.status or "").upper() == "PRESENT"
        )

        absent_count = 0
        for row in today_attendance:
            status = (row.status or "").upper()
            remarks = (row.remarks or "").strip().lower()
            if status == "ABSENT" and "leave" not in remarks:
                absent_count += 1

        leave_today_count = 0
        for leave in all_active_leaves_today:
            owner = faculty_map.get(leave.faculty_id)
            if owner and _safe_str(owner.department) == dept_name:
                leave_today_count += 1

        total_staff = len(dept_users)
        attendance_percent = (
            round((present_count / total_staff) * 100, 1) if total_staff else 0.0
        )

        missing_roles = []
        if not hod_user:
            missing_roles.append("HOD")
        if not operator_user:
            missing_roles.append("Operator")

        results.append(
            {
                "department": dept_name,
                "total_staff": total_staff,
                "present_today": present_count,
                "absent_today": absent_count,
                "on_leave_today": leave_today_count,
                "attendance_percent": attendance_percent,
                "hod_name": hod_user.name if hod_user else None,
                "operator_name": operator_user.name if operator_user else None,
                "has_hod": hod_user is not None,
                "has_operator": operator_user is not None,
                "needs_attention": len(missing_roles) > 0,
                "missing_roles": missing_roles,
            }
        )

    return results


def get_admin_attendance_overview(
    db: Session,
    start_date: date | None = None,
    end_date: date | None = None,
) -> dict:
    query = db.query(Attendance)

    if start_date:
        query = query.filter(Attendance.date >= start_date)

    if end_date:
        query = query.filter(Attendance.date <= end_date)

    records = query.order_by(Attendance.date.desc()).all()

    present_count = 0
    absent_count = 0
    leave_count = 0
    total_working_hours = 0.0
    auto_marked_absent = 0
    late_entries = 0

    for row in records:
        remarks = (row.remarks or "").strip().lower()
        status = (row.status or "").upper()

        total_working_hours += float(row.working_hours or 0.0)

        if "leave" in remarks:
            leave_count += 1
        elif status == "PRESENT":
            present_count += 1
        elif status == "ABSENT":
            absent_count += 1

        if row.auto_marked and status == "ABSENT":
            auto_marked_absent += 1

        if "late" in remarks:
            late_entries += 1

    total_records = len(records)

    return {
        "start_date": str(start_date) if start_date else None,
        "end_date": str(end_date) if end_date else None,
        "total_records": total_records,
        "present_records": present_count,
        "absent_records": absent_count,
        "leave_records": leave_count,
        "late_entries": late_entries,
        "auto_marked_absent": auto_marked_absent,
        "total_working_hours": round(total_working_hours, 2),
    }