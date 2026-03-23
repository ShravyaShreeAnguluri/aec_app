from typing import Optional
from pydantic import BaseModel, model_validator


def _csv_is_valid_int_list(value: Optional[str]) -> bool:
    """Check that a string is a valid comma-separated list of integers."""
    if value is None or value.strip() == "":
        return True
    try:
        for part in value.split(","):
            part = part.strip()
            if part == "":
                continue
            int(part)
        return True
    except ValueError:
        return False


def _parse_csv_ints(value: Optional[str]) -> list:
    if not value:
        return []
    result = []
    for part in value.split(","):
        part = part.strip()
        if part:
            result.append(int(part))
    return result


class SectionCreate(BaseModel):
    department_id: int
    name: str
    year: int
    semester: int
    academic_year: str

    # THUB / NON_THUB / REGULAR
    category: str

    # Room assigned to this section e.g. "BGB-111"
    classroom: Optional[str] = None

    # Always 8: 7 teaching periods + 1 lunch slot
    total_periods_per_day: int = 8

    # Which slot index is lunch (0-based)
    # For most sections this is 3 (after 3rd period)
    lunch_after_period: int = 3
    lunch_label: Optional[str] = "LUNCH"

    # Working days as CSV of day indexes
    # NON_THUB II yr (Sat holiday): "0,1,2,3,4"
    # All III yr and THUB II yr (Sat college): "0,1,2,3,4,5"
    working_days: str = "0,1,2,3,4,5"

    # T-Hub reserved period indexes as CSV e.g. "0,1,2"
    # Only needed for THUB sections
    thub_reserved_periods: Optional[str] = None

    # Duration of each teaching slot in minutes (default 50)
    slot_duration_minutes: int = 50

    # Duration of lunch break in minutes
    # II yr = 50 min, III yr = 60 min - operator sets this
    lunch_duration_minutes: int = 60

    # Start time of first period e.g. "09:30"
    # Operator sets this - default is 09:30 for your college
    start_time: str = "09:30"

    @model_validator(mode="after")
    def validate_section(self):
        if self.total_periods_per_day != 8:
            raise ValueError("This version supports exactly 8 slots per day including lunch.")

        if self.lunch_after_period < 0 or self.lunch_after_period > 7:
            raise ValueError("lunch_after_period must be between 0 and 7.")

        if self.category not in ["THUB", "NON_THUB", "REGULAR"]:
            raise ValueError("category must be THUB, NON_THUB, or REGULAR.")

        if not _csv_is_valid_int_list(self.working_days):
            raise ValueError("working_days must be a comma-separated list of integers e.g. '0,1,2,3,4'.")

        # Validate working day values are in range 0-6
        for d in _parse_csv_ints(self.working_days):
            if d < 0 or d > 6:
                raise ValueError(f"working_days contains invalid day index {d}. Must be 0 (Mon) to 6 (Sun).")

        if not _csv_is_valid_int_list(self.thub_reserved_periods):
            raise ValueError("thub_reserved_periods must be a comma-separated list of integers.")

        # NON_THUB section should not have thub_reserved_periods
        if self.category == "NON_THUB" and self.thub_reserved_periods:
            raise ValueError("NON_THUB sections should not have thub_reserved_periods.")

        # THUB section should have thub_reserved_periods set
        if self.category == "THUB" and not self.thub_reserved_periods:
            raise ValueError("THUB sections must have thub_reserved_periods set (e.g. '0,1,2' for first 3 periods).")

        # Validate start_time format
        try:
            h, m = self.start_time.split(":")
            if not (0 <= int(h) <= 23 and 0 <= int(m) <= 59):
                raise ValueError()
        except Exception:
            raise ValueError("start_time must be in HH:MM format e.g. '09:30'.")

        return self


class SubjectCreate(BaseModel):
    department_id: int
    year: int
    semester: int
    academic_year: str

    code: str
    name: str
    short_name: str

    # THEORY / LAB / ACTIVITY / THUB / FIP / PSA / OTHER
    subject_type: str

    # Default weekly hours - used when category-specific not set
    weekly_hours: int = 0

    # Set these when THUB and NON_THUB sections need different class counts
    # e.g. a lab: NON_THUB gets 3 hrs/week, THUB gets 2 hrs/week
    weekly_hours_non_thub: Optional[int] = None
    weekly_hours_thub: Optional[int] = None

    is_lab: bool = False

    # How many consecutive periods per sitting
    # Labs: usually min=3, max=3
    # CRT blocks: min=2, max=2
    # Normal theory: min=1, max=1
    min_continuous_periods: int = 1
    max_continuous_periods: int = 1

    requires_room_type: Optional[str] = None  # CLASSROOM / LAB / NONE
    default_room_name: Optional[str] = None

    # --- Fixed subject settings ---
    is_fixed: bool = False

    # Option 1: fixed on ONE specific day e.g. fixed_day=0 means every Monday
    fixed_day: Optional[int] = None

    # Option 2: fixed on MULTIPLE specific days e.g. fixed_days="0,2,4"
    fixed_days: Optional[str] = None

    # Option 3: fixed on EVERY working day of the section
    # Use this for FIP (last period every day) - no need to type all day numbers
    fixed_every_working_day: bool = False

    # Which period slot to place this subject on (0-based)
    # e.g. 7 = last period (P8) for FIP
    fixed_start_period: Optional[int] = None

    # How many consecutive periods to occupy (default 1)
    fixed_span: int = 1

    # Restrict placement to specific days/periods
    # e.g. PSA only on certain days: allowed_days="1,3"
    allowed_days: Optional[str] = None
    allowed_periods: Optional[str] = None

    # True for FIP, THUB blocks - no faculty needed
    no_faculty_required: bool = False

    # True if this subject can repeat on the same day
    # e.g. NLP had 2 periods on Friday in CSE-A
    allow_same_day_repeat: bool = False

    notes: Optional[str] = None

    applies_to_category: Optional[str] = None  # None = all, "NON_THUB", "THUB"

    @model_validator(mode="after")
    def validate_subject(self):
        valid_types = ["THEORY", "LAB", "ACTIVITY", "THUB", "FIP", "PSA", "OTHER"]
        if self.subject_type not in valid_types:
            raise ValueError(f"subject_type must be one of: {', '.join(valid_types)}")

        if self.min_continuous_periods < 1 or self.max_continuous_periods < 1:
            raise ValueError("Continuous periods must be >= 1.")

        if self.min_continuous_periods > self.max_continuous_periods:
            raise ValueError("min_continuous_periods cannot be greater than max_continuous_periods.")

        # Lab hours must divide evenly by min_continuous_periods
        # e.g. 3 hrs/week with min=3 is fine (one 3-period block)
        # e.g. 5 hrs/week with min=3 is impossible - catch it here
        for hours_field in ["weekly_hours", "weekly_hours_non_thub", "weekly_hours_thub"]:
            hrs = getattr(self, hours_field)
            if hrs is not None and hrs > 0 and self.min_continuous_periods > 1:
                if hrs % self.min_continuous_periods != 0:
                    raise ValueError(
                        f"{hours_field}={hrs} is not divisible by "
                        f"min_continuous_periods={self.min_continuous_periods}. "
                        f"Lab sessions cannot be split - adjust hours or min_continuous_periods."
                    )

        # Fixed subject validations
        if self.is_fixed:
            # Must have exactly one of the three day options
            day_options = [
                self.fixed_day is not None,
                bool(self.fixed_days),
                self.fixed_every_working_day,
            ]
            if sum(day_options) == 0:
                raise ValueError(
                    "Fixed subject must have one of: fixed_day, fixed_days, or fixed_every_working_day=True."
                )
            if sum(day_options) > 1:
                raise ValueError(
                    "Fixed subject must use only ONE of: fixed_day, fixed_days, or fixed_every_working_day."
                )

            if self.fixed_start_period is None:
                raise ValueError("Fixed subject must have fixed_start_period set.")

            if self.fixed_day is not None and not (0 <= self.fixed_day <= 5):
                raise ValueError("fixed_day must be between 0 (Mon) and 5 (Sat).")

            if self.fixed_start_period is not None and not (0 <= self.fixed_start_period <= 7):
                raise ValueError("fixed_start_period must be between 0 and 7.")

            if self.fixed_span < 1:
                raise ValueError("fixed_span must be >= 1.")

        if not _csv_is_valid_int_list(self.fixed_days):
            raise ValueError("fixed_days must be a comma-separated list of integers.")

        if not _csv_is_valid_int_list(self.allowed_days):
            raise ValueError("allowed_days must be a comma-separated list of integers.")

        if not _csv_is_valid_int_list(self.allowed_periods):
            raise ValueError("allowed_periods must be a comma-separated list of integers.")

        # THUB subject type should not need faculty
        if self.subject_type == "THUB" and not self.no_faculty_required:
            raise ValueError(
                "THUB type subjects have no faculty. Set no_faculty_required=True."
            )

        # FIP should have no faculty and be fixed every working day
        if self.subject_type == "FIP":
            if not self.no_faculty_required:
                raise ValueError("FIP subjects have no faculty. Set no_faculty_required=True.")
            if not self.is_fixed:
                raise ValueError("FIP subjects must be fixed (is_fixed=True).")

        if self.applies_to_category is not None and self.applies_to_category not in ["THUB", "NON_THUB", "REGULAR"]:
            raise ValueError("applies_to_category must be THUB, NON_THUB, REGULAR or null.")

        return self


class FacultySubjectMapCreate(BaseModel):
    faculty_public_id: str
    subject_id: int

    # Lower number = higher priority
    # 1 = primary teacher for this subject
    # 2,3 = backup teachers used when primary is busy
    priority: int = 1

    # Max periods per week this faculty teaches this subject
    # Leave None for no limit
    max_hours_per_week: Optional[int] = None

    # Max periods per day - college rule is 7 max
    max_hours_per_day: Optional[int] = 7

    # Can this faculty handle the lab version of this subject?
    can_handle_lab: bool = True

    # True = main assigned teacher, False = secondary/backup
    is_primary: bool = True


class RoomCreate(BaseModel):
    department_id: Optional[int] = None
    name: str
    room_type: str      # CLASSROOM / LAB
    capacity: Optional[int] = None

    @model_validator(mode="after")
    def validate_room(self):
        if self.room_type not in ["CLASSROOM", "LAB"]:
            raise ValueError("room_type must be CLASSROOM or LAB.")
        return self


class GenerateTimetableRequest(BaseModel):
    department_id: int
    academic_year: str