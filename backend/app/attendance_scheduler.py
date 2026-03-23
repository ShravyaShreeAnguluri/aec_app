from datetime import date
from app.database import SessionLocal
from app.models import Faculty, Attendance
from app.holiday.holiday_service import validate_attendance_not_holiday
from app.leave.leave_models import Leave
from apscheduler.schedulers.background import BackgroundScheduler

def auto_mark_absent():
    db = SessionLocal()
    try:
        today = date.today()

        # skip holidays / Sundays
        try:
            validate_attendance_not_holiday(db, today)
        except Exception:
            print("Holiday or Sunday — skipping auto absent")
            return

        faculty_list = db.query(Faculty).all()

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

                # Full day leave
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

                # Morning half-day leave but no afternoon attendance marked
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

                # Afternoon half-day leave but no morning attendance marked
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

            # No leave and no attendance -> absent
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