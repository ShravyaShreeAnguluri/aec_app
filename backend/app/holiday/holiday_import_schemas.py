from pydantic import BaseModel
from typing import List


class ImportedHolidayItem(BaseModel):
    title: str
    start_date: str
    end_date: str


class HolidayImportConfirmRequest(BaseModel):
    holidays: List[ImportedHolidayItem]