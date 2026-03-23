from sqlalchemy.orm import Session
from .holiday_models import Holiday


def create_holiday(db: Session, data, admin_id):
    holiday = Holiday(
        title=data.title,
        date=data.date,
        type=data.type,
        description=data.description,
        created_by=admin_id
    )

    db.add(holiday)
    db.commit()
    db.refresh(holiday)
    return holiday


def get_all_holidays(db: Session):
    return db.query(Holiday).order_by(Holiday.date).all()


def delete_holiday(db: Session, holiday_id):
    holiday = db.query(Holiday).filter(Holiday.id == holiday_id).first()

    if holiday:
        db.delete(holiday)
        db.commit()

    return {"message": "Holiday removed"}


def is_holiday(db: Session, check_date):
    return db.query(Holiday).filter(Holiday.date == check_date).first()