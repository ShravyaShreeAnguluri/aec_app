from pydantic import BaseModel
from datetime import date
from typing import Optional

class LeaveApply(BaseModel):

    start_date: date
    end_date: date
    leave_type: str
    reason: str
    permission_duration: Optional[str] = None