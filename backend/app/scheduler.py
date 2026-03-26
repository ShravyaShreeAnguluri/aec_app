from datetime import date
from apscheduler.schedulers.background import BackgroundScheduler
from app.database import SessionLocal
from app.models import Faculty, Attendance
from app.leave.leave_crud import auto_escalate_leaves
from app.leave.leave_models import Leave
from app.holiday.holiday_service import validate_attendance_not_holiday

ALLOWED_ATTENDANCE_ROLES = ["faculty", "hod", "dean", "operator"]

def auto_mark_absent():
    db = SessionLocal()
    try:
        today = date.today()

        # Skip holidays / Sundays
        try:
            validate_attendance_not_holiday(db, today)
        except Exception:
            print("Holiday or Sunday - skipping auto absent")
            return

        faculty_list = db.query(Faculty).filter(
            Faculty.role.in_(ALLOWED_ATTENDANCE_ROLES)
        ).all()

        for faculty in faculty_list:
            existing = db.query(Attendance).filter(
                Attendance.faculty_id == faculty.faculty_id,
                Attendance.date == today
            ).first()

            if existing:
                continue

            approved_leave = db.query(Leave).filter(
                Leave.faculty_id == faculty.faculty_id,
                Leave.status == "APPROVED",
                Leave.start_date <= today,
                Leave.end_date >= today
            ).first()

            if approved_leave:
                leave_part = (approved_leave.permission_duration or "").strip().lower()

                if leave_part in ["full day", "full_day", ""]:
                    attendance = Attendance(
                        faculty_id=faculty.faculty_id,
                        faculty_name=faculty.name,
                        date=today,
                        clock_in_time=None,
                        clock_out_time=None,
                        status="ABSENT",
                        remarks="On Leave",
                        day_fraction=0.0,
                        used_permission=False,
                        auto_marked=False,
                        working_hours=0.0
                    )
                    db.add(attendance)
                    db.commit()
                    continue

                elif leave_part in ["half day morning", "half_day_morning"]:
                    attendance = Attendance(
                        faculty_id=faculty.faculty_id,
                        faculty_name=faculty.name,
                        date=today,
                        clock_in_time=None,
                        clock_out_time=None,
                        status="PRESENT",
                        remarks="Half Day - Morning Leave",
                        day_fraction=0.5,
                        used_permission=False,
                        auto_marked=True,
                        working_hours=0.0
                    )
                    db.add(attendance)
                    db.commit()
                    continue

                elif leave_part in ["half day afternoon", "half_day_afternoon"]:
                    attendance = Attendance(
                        faculty_id=faculty.faculty_id,
                        faculty_name=faculty.name,
                        date=today,
                        clock_in_time=None,
                        clock_out_time=None,
                        status="PRESENT",
                        remarks="Half Day - Afternoon Leave",
                        day_fraction=0.5,
                        used_permission=False,
                        auto_marked=True,
                        working_hours=0.0
                    )
                    db.add(attendance)
                    db.commit()
                    continue

            attendance = Attendance(
                faculty_id=faculty.faculty_id,
                faculty_name=faculty.name,
                date=today,
                clock_in_time=None,
                clock_out_time=None,
                status="ABSENT",
                remarks="Absent",
                day_fraction=0.0,
                used_permission=False,
                auto_marked=True,
                working_hours=0.0
            )
            db.add(attendance)
            db.commit()

        print("Auto absent completed")

    except Exception as e:
        db.rollback()
        print("Auto absent error:", e)
    finally:
        db.close()

def run_leave_escalation():
    db = SessionLocal()
    try:
        auto_escalate_leaves(db)
    finally:
        db.close()

def start_scheduler():
    scheduler = BackgroundScheduler(timezone="Asia/Kolkata")

    scheduler.add_job(
        run_leave_escalation,
        "interval",
        minutes=30,
        id="leave_escalation"
    )

    scheduler.add_job(
        auto_mark_absent,
        "cron",
        hour=16,
        minute=30,
        id="auto_absent_job"
    )

    scheduler.start()
    print("Scheduler started successfully")