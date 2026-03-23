from datetime import date, timedelta, datetime
from fastapi import HTTPException
from sqlalchemy.orm import Session
from app.holiday.holiday_models import Holiday
import requests


def is_sunday(check_date: date) -> bool:
    return check_date.weekday() == 6  # Sunday

def get_working_leave_days(db: Session, start_date: date, end_date: date):
    current = start_date
    working_days = []
    excluded_days = []

    while current <= end_date:
        result = check_holiday(db, current)

        if result["is_holiday"]:
            excluded_days.append({
                "date": current,
                "reason": result["reason"]
            })
        else:
            working_days.append(current)

        current += timedelta(days=1)
    return {
        "working_days": working_days,
        "excluded_days": excluded_days,
        "total_working_days": len(working_days)
    }

def validate_leave_range_has_working_day(db: Session, start_date: date, end_date: date):
    summary = get_working_leave_days(db, start_date, end_date)

    if summary["total_working_days"] == 0:
        raise HTTPException(
            status_code=400,
            detail="Selected range contains only holidays/Sundays. Leave cannot be applied."
        )

    return summary
    
def get_active_holiday_by_date(db: Session, check_date: date):
    return db.query(Holiday).filter(
        Holiday.start_date <= check_date,
        Holiday.end_date >= check_date,
        Holiday.is_active == True
    ).first()


def check_holiday(db: Session, check_date: date):
    if is_sunday(check_date):
        return {
            "date": check_date,
            "is_holiday": True,
            "reason": "Sunday",
            "holiday": None
        }

    holiday = get_active_holiday_by_date(db, check_date)
    if holiday:
        return {
            "date": check_date,
            "is_holiday": True,
            "reason": holiday.title,
            "holiday": holiday
        }

    return {
        "date": check_date,
        "is_holiday": False,
        "reason": "Working day",
        "holiday": None
    }


def create_holiday(db: Session, data):
    if data.end_date < data.start_date:
        raise HTTPException(status_code=400, detail="End date cannot be before start date.")

    existing = db.query(Holiday).filter(
        Holiday.title == data.title,
        Holiday.start_date == data.start_date,
        Holiday.end_date == data.end_date
    ).first()

    if existing:
        raise HTTPException(status_code=400, detail="This holiday already exists.")

    holiday = Holiday(
        title=data.title,
        start_date=data.start_date,
        end_date=data.end_date,
        description=data.description,
        holiday_type=data.holiday_type,
        is_active=data.is_active
    )

    db.add(holiday)
    db.commit()
    db.refresh(holiday)
    return holiday


def update_holiday(db: Session, holiday_id: int, data):
    holiday = db.query(Holiday).filter(Holiday.id == holiday_id).first()
    if not holiday:
        raise HTTPException(status_code=404, detail="Holiday not found.")

    new_start_date = data.start_date if data.start_date is not None else holiday.start_date
    new_end_date = data.end_date if data.end_date is not None else holiday.end_date

    if new_end_date < new_start_date:
        raise HTTPException(status_code=400, detail="End date cannot be before start date.")

    if data.title is not None:
        holiday.title = data.title
    if data.start_date is not None:
        holiday.start_date = data.start_date
    if data.end_date is not None:
        holiday.end_date = data.end_date
    if data.description is not None:
        holiday.description = data.description
    if data.holiday_type is not None:
        holiday.holiday_type = data.holiday_type
    if data.is_active is not None:
        holiday.is_active = data.is_active

    db.commit()
    db.refresh(holiday)
    return holiday


def delete_holiday(db: Session, holiday_id: int):
    holiday = db.query(Holiday).filter(Holiday.id == holiday_id).first()
    if not holiday:
        raise HTTPException(status_code=404, detail="Holiday not found or already removed.")

    db.delete(holiday)
    db.commit()
    return {"message": "Holiday deleted successfully."}


def get_all_holidays(db: Session):
    return db.query(Holiday).order_by(Holiday.start_date.asc()).all()


def get_month_holidays(db: Session, year: int, month: int):
    month_start = date(year, month, 1)

    if month == 12:
        month_end = date(year + 1, 1, 1) - timedelta(days=1)
    else:
        month_end = date(year, month + 1, 1) - timedelta(days=1)

    return db.query(Holiday).filter(
        Holiday.start_date <= month_end,
        Holiday.end_date >= month_start
    ).order_by(Holiday.start_date.asc()).all()


def validate_attendance_not_holiday(db: Session, today_date: date):
    result = check_holiday(db, today_date)
    if result["is_holiday"]:
        raise HTTPException(
            status_code=400,
            detail=f"Attendance cannot be marked on holidays or Sundays. Today is {result['reason']}."
        )

def fetch_public_holidays_from_api(db: Session, year: int, country_code: str = "IN"):
    url = f"https://date.nager.at/api/v3/PublicHolidays/{year}/{country_code}"

    try:
        response = requests.get(url, timeout=20)
        print("PUBLIC HOLIDAY API URL:", url)
        print("PUBLIC HOLIDAY API STATUS:", response.status_code)
        print("PUBLIC HOLIDAY API RESPONSE:", response.text[:500])

        response.raise_for_status()
        holidays_data = response.json()

    except requests.exceptions.RequestException as e:
        print("PUBLIC HOLIDAY API REQUEST ERROR:", str(e))
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch public holidays from API: {str(e)}"
        )
    except ValueError:
        raise HTTPException(
            status_code=500,
            detail="Invalid response received from public holiday API."
        )

    added_count = 0

    for item in holidays_data:
        try:
            holiday_date = datetime.strptime(item["date"], "%Y-%m-%d").date()
            title = item.get("localName") or item.get("name") or "Public Holiday"

            existing = db.query(Holiday).filter(
                Holiday.start_date == holiday_date,
                Holiday.end_date == holiday_date,
                Holiday.title == title
            ).first()
            if existing:
                continue

            holiday = Holiday(
                title=title,
                start_date=holiday_date,
                end_date=holiday_date,
                description=item.get("name"),
                holiday_type="PUBLIC",
                is_active=True
            )
            db.add(holiday)
            added_count += 1

        except Exception as e:
            print("HOLIDAY SAVE ERROR:", str(e))
            continue

    db.commit()

    return {
        "message": f"{added_count} public holidays fetched successfully.",
        "count": added_count
    }