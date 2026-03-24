from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    ForeignKey,
    UniqueConstraint,
    Text,
)
from app.database import Base


class TimetableSection(Base):
    __tablename__ = "tt_sections"

    id = Column(Integer, primary_key=True, index=True)
    department_id = Column(Integer, ForeignKey("departments.id"), nullable=False)

    name = Column(String, nullable=False)           # CSE-A, CSE-6, CSE-9
    year = Column(Integer, nullable=False)
    semester = Column(Integer, nullable=False)
    academic_year = Column(String, nullable=False)

    # THUB / NON_THUB / REGULAR
    category = Column(String, nullable=False)
    classroom = Column(String, nullable=True)

    # total slots per day INCLUDING the lunch slot
    # e.g. 8 means 7 teaching periods + 1 lunch
    total_periods_per_day = Column(Integer, nullable=False, default=8)

    # which period index is lunch (0-based)
    # e.g. 3 means after 3rd teaching period
    lunch_after_period = Column(Integer, nullable=False, default=3)
    lunch_label = Column(String, nullable=True, default="LUNCH")

    # CSV of working day indexes.
    # Mon-Fri => "0,1,2,3,4"   (II yr NON_THUB - Saturday holiday)
    # Mon-Sat => "0,1,2,3,4,5" (III yr all, II yr THUB)
    working_days = Column(String, nullable=False, default="0,1,2,3,4,5")

    # THUB reserved period indexes as CSV e.g. "0,1,2" means P1,P2,P3 are T-Hub
    thub_reserved_periods = Column(String, nullable=True)

    # Duration of each teaching slot in minutes
    slot_duration_minutes = Column(Integer, nullable=False, default=50)

    # Duration of lunch in minutes
    # II yr sections = 50 min, III yr sections = 60 min
    lunch_duration_minutes = Column(Integer, nullable=False, default=60)

    # Start time of first period e.g. "09:30"
    # Operator sets this per section - do NOT hardcode
    start_time = Column(String, nullable=False, default="09:30")

    created_by = Column(String, nullable=True)

    __table_args__ = (
        UniqueConstraint(
            "department_id",
            "name",
            "academic_year",
            name="uq_tt_sections_department_name_ay",
        ),
    )


class TimetableSubject(Base):
    __tablename__ = "tt_subjects"

    id = Column(Integer, primary_key=True, index=True)
    department_id = Column(Integer, ForeignKey("departments.id"), nullable=False)

    year = Column(Integer, nullable=False)
    semester = Column(Integer, nullable=False)
    academic_year = Column(String, nullable=False)

    code = Column(String, nullable=False)
    name = Column(String, nullable=False)
    short_name = Column(String, nullable=False)

    # THEORY / LAB / ACTIVITY / THUB / FIP / PSA / OTHER
    subject_type = Column(String, nullable=False)

    # Default weekly hours (used when category-specific not set)
    weekly_hours = Column(Integer, nullable=False, default=0)

    # Set these separately when THUB and NON_THUB need different hours
    # e.g. Lab: NON_THUB=3, THUB=2
    weekly_hours_non_thub = Column(Integer, nullable=True)
    weekly_hours_thub = Column(Integer, nullable=True)

    is_lab = Column(Boolean, nullable=False, default=False)

    min_continuous_periods_thub = Column(Integer, nullable=True)
    max_continuous_periods_thub = Column(Integer, nullable=True)
    min_continuous_periods_non_thub = Column(Integer, nullable=True)
    max_continuous_periods_non_thub = Column(Integer, nullable=True)
    # For labs: how many consecutive periods in one sitting
    # e.g. min=3, max=3 means always place 3 together
    # For CRT blocks: min=2, max=2
    min_continuous_periods = Column(Integer, nullable=False, default=1)
    max_continuous_periods = Column(Integer, nullable=False, default=1)

    requires_room_type = Column(String, nullable=True)  # CLASSROOM / LAB / NONE
    default_room_name = Column(String, nullable=True)

    # --- Fixed subject settings ---
    is_fixed = Column(Boolean, nullable=False, default=False)

    # Use fixed_day (single day) OR fixed_days (CSV of days)
    fixed_day = Column(Integer, nullable=True)
    fixed_days = Column(String, nullable=True)

    # NEW: if True, subject is placed at fixed_start_period on EVERY working day
    # of the section. Operator just sets this True + fixed_start_period.
    # Used for FIP which appears last period every single day.
    # No need to manually type all day numbers.
    fixed_every_working_day = Column(Boolean, nullable=False, default=False)

    fixed_start_period = Column(Integer, nullable=True)
    fixed_span = Column(Integer, nullable=False, default=1)

    # Restrict which days / periods this subject can be placed on
    # e.g. allowed_days="0,1,2" means only Mon/Tue/Wed
    allowed_days = Column(String, nullable=True)
    allowed_periods = Column(String, nullable=True)

    # True for FIP, T-Hub blocks etc. - no faculty assigned
    no_faculty_required = Column(Boolean, nullable=False, default=False)

    # True = allowed to appear twice in same day (e.g. NLP had 2 on Fri in CSE-A)
    allow_same_day_repeat = Column(Boolean, nullable=False, default=False)
    # In timetable_models.py TimetableSubject
    applies_to_category = Column(String, nullable=True)  
    # NULL = applies to all, "NON_THUB" = only NON_THUB, "THUB" = only THUB

    notes = Column(Text, nullable=True)

    __table_args__ = (
        UniqueConstraint(
            "department_id",
            "year",
            "semester",
            "academic_year",
            "code",
            name="uq_tt_subjects_department_year_sem_ay_code",
        ),
    )


class FacultySubjectMap(Base):
    __tablename__ = "tt_faculty_subject_map"

    id = Column(Integer, primary_key=True, index=True)
    faculty_id = Column(Integer, ForeignKey("faculty.id"), nullable=False)
    subject_id = Column(Integer, ForeignKey("tt_subjects.id"), nullable=False)

    # Lower number = higher priority when picking faculty
    priority = Column(Integer, nullable=False, default=1)

    # Hard limits set by operator per faculty per subject
    max_hours_per_week = Column(Integer, nullable=True)
    max_hours_per_day = Column(Integer, nullable=True)   # default 7 in generator

    can_handle_lab = Column(Boolean, nullable=False, default=True)

    # is_primary=True means this faculty is the main assigned teacher
    # is_primary=False means backup/secondary (used when primary is busy)
    is_primary = Column(Boolean, nullable=False, default=True)

    __table_args__ = (
        UniqueConstraint(
            "faculty_id",
            "subject_id",
            name="uq_tt_faculty_subject_map_faculty_subject",
        ),
    )


class TimetableRoom(Base):
    __tablename__ = "tt_rooms"

    id = Column(Integer, primary_key=True, index=True)
    department_id = Column(Integer, ForeignKey("departments.id"), nullable=True)

    name = Column(String, unique=True, nullable=False)
    room_type = Column(String, nullable=False)  # CLASSROOM / LAB
    capacity = Column(Integer, nullable=True)


class TimetableEntry(Base):
    __tablename__ = "tt_entries"

    id = Column(Integer, primary_key=True, index=True)

    section_id = Column(Integer, ForeignKey("tt_sections.id"), nullable=False)
    subject_id = Column(Integer, ForeignKey("tt_subjects.id"), nullable=True)
    faculty_id = Column(Integer, ForeignKey("faculty.id"), nullable=True)
    room_id = Column(Integer, ForeignKey("tt_rooms.id"), nullable=True)

    day_index = Column(Integer, nullable=False)     # 0=Mon .. 5=Sat
    period_index = Column(Integer, nullable=False)  # 0-based slot index

    # THEORY / LAB / LUNCH / BLOCKED / THUB / FIP / PSA / ACTIVITY
    slot_type = Column(String, nullable=False)
    is_fixed = Column(Boolean, nullable=False, default=False)
    is_lab_continuation = Column(Boolean, nullable=False, default=False)

    __table_args__ = (
        UniqueConstraint(
            "section_id",
            "day_index",
            "period_index",
            name="uq_tt_entries_section_day_period",
        ),
    )