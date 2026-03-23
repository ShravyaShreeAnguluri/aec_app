from datetime import date
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.utils.auth_dependency import get_current_user
from app.holiday.holiday_schemas import (
    HolidayCreate,
    HolidayUpdate,
    HolidayResponse,
    HolidayCheckResponse,
)
from app.holiday.holiday_service import (
    create_holiday,
    update_holiday,
    delete_holiday,
    get_all_holidays,
    get_month_holidays,
    check_holiday,
    fetch_public_holidays_from_api,
)
from app.holiday.holiday_import_schemas import HolidayImportConfirmRequest
from app.holiday.holiday_pdf_import_service import (
    preview_holidays_from_pdf,
    confirm_import_holidays,
)

router = APIRouter(prefix="/holidays", tags=["Holidays"])


def require_admin(user):
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Only admin can manage holidays.")


@router.get("/", response_model=list[HolidayResponse])
def list_holidays(
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    return get_all_holidays(db)


@router.get("/check", response_model=HolidayCheckResponse)
def check_date_holiday(
    check_date: date = Query(...),
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    return check_holiday(db, check_date)


@router.get("/today", response_model=HolidayCheckResponse)
def today_holiday(
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    return check_holiday(db, date.today())


@router.get("/calendar", response_model=list[HolidayResponse])
def holiday_calendar(
    year: int = Query(...),
    month: int = Query(...),
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    return get_month_holidays(db, year, month)


@router.post("/", response_model=HolidayResponse)
def add_holiday(
    data: HolidayCreate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    require_admin(user)
    return create_holiday(db, data)


@router.put("/{holiday_id}", response_model=HolidayResponse)
def edit_holiday(
    holiday_id: int,
    data: HolidayUpdate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    require_admin(user)
    return update_holiday(db, holiday_id, data)


@router.delete("/{holiday_id}")
def remove_holiday(
    holiday_id: int,
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    require_admin(user)
    return delete_holiday(db, holiday_id)


@router.post("/fetch-public")
def fetch_public_holidays(
    year: int = Query(...),
    country_code: str = Query("IN"),
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    require_admin(user)
    return fetch_public_holidays_from_api(db, year, country_code)


@router.post("/import-pdf-preview")
async def import_holiday_pdf_preview(
    pdf_file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    require_admin(user)
    return await preview_holidays_from_pdf(pdf_file)


@router.post("/import-pdf-confirm")
def import_holiday_pdf_confirm(
    payload: HolidayImportConfirmRequest,
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    require_admin(user)
    return confirm_import_holidays(db, [item.dict() for item in payload.holidays])