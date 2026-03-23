from pydantic import BaseModel, field_validator
from datetime import date, datetime
from typing import Optional


class HolidayBase(BaseModel):
    title: str
    start_date: date
    end_date: date
    description: Optional[str] = None
    holiday_type: str = "CUSTOM"
    is_active: bool = True

    @field_validator("title")
    @classmethod
    def validate_title(cls, v: str):
        if not v or not v.strip():
            raise ValueError("Holiday title is required.")
        return v.strip()

    @field_validator("holiday_type")
    @classmethod
    def validate_holiday_type(cls, v: str):
        v = v.strip().upper()
        if v not in ["PUBLIC", "CUSTOM"]:
            raise ValueError("Holiday type must be PUBLIC or CUSTOM.")
        return v

    @field_validator("end_date")
    @classmethod
    def validate_dates(cls, v, info):
        start_date = info.data.get("start_date")
        if start_date and v < start_date:
            raise ValueError("End date cannot be before start date.")
        return v


class HolidayCreate(HolidayBase):
    pass


class HolidayUpdate(BaseModel):
    title: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    description: Optional[str] = None
    holiday_type: Optional[str] = None
    is_active: Optional[bool] = None


class HolidayResponse(BaseModel):
    id: int
    title: str
    start_date: date
    end_date: date
    description: Optional[str]
    holiday_type: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class HolidayCheckResponse(BaseModel):
    date: date
    is_holiday: bool
    reason: str
    holiday: Optional[HolidayResponse] = None