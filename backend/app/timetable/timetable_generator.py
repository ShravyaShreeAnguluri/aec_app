from collections import defaultdict
from sqlalchemy.orm import Session
from app.models import Faculty
from .timetable_models import (
    TimetableSection,
    TimetableSubject,
    FacultySubjectMap,
    TimetableRoom,
    TimetableEntry,
)
from .timetable_utils import (
    is_working_day,
    is_lunch_slot,
    is_thub_reserved_slot,
    slot_allowed_by_subject,
    get_working_days,
    get_day_range,
    get_subject_weekly_hours_for_section,
    subject_applies_to_section,
    validate_section_subject_feasibility,
    get_subject_continuous_span_for_section,
    parse_csv_ints,
)


class TimetableGenerationError(Exception):
    pass


class TimetableGenerator:
    def __init__(self, db: Session, department_id: int, academic_year: str):
        self.db = db
        self.department_id = department_id
        self.academic_year = academic_year

        self.sections = []
        self.rooms = []
        self.room_map = {}
        self.faculty_map = {}

        self.subjects_by_key = defaultdict(list)
        self.preferences_by_subject = defaultdict(list)

        self.errors = []

        # In-memory conflict tracking
        self.section_busy = set()       # (section_id, day, period)
        self.faculty_busy = set()       # (faculty_id, day, period)
        self.room_busy = set()          # (room_id, day, period)

        self.faculty_day_hours = defaultdict(int)   # (faculty_id, day) -> count
        self.faculty_week_hours = defaultdict(int)  # faculty_id -> count

        self.subject_day_tracker = set()            # (section_id, subject_id, day)
        self.section_day_load = defaultdict(int)    # (section_id, day) -> count
        self.subject_total_placed = defaultdict(int)
        self.subject_slot_tracker = defaultdict(int)
        self.section_subject_slot_tracker = defaultdict(int)
        self.section_lab_days = defaultdict(set)      # (section_id, subject_id) -> {days}
        self.section_free_periods = defaultdict(set)  # (section_id, day) -> free teaching periods
        self.section_subject_periods = defaultdict(list)

    # ------------------------------------------------------------------
    # Weekly hours helper
    # ------------------------------------------------------------------
    def _get_weekly_hours(self, section, subject):
        return get_subject_weekly_hours_for_section(subject, section)

    # ------------------------------------------------------------------
    # Load all data from DB
    # ------------------------------------------------------------------
    def load_master_data(self):
        self.sections = (
            self.db.query(TimetableSection)
            .filter(
                TimetableSection.department_id == self.department_id,
                TimetableSection.academic_year == self.academic_year,
            )
            .order_by(
                TimetableSection.year,
                TimetableSection.semester,
                TimetableSection.category,
                TimetableSection.name,
            )
            .all()
        )

        subjects = (
            self.db.query(TimetableSubject)
            .filter(
                TimetableSubject.department_id == self.department_id,
                TimetableSubject.academic_year == self.academic_year,
            )
            .order_by(
                TimetableSubject.year,
                TimetableSubject.semester,
                TimetableSubject.code,
            )
            .all()
        )

        for subject in subjects:
            self.subjects_by_key[(subject.year, subject.semester)].append(subject)

        dept_subject_ids = {s.id for s in subjects}
        mappings = self.db.query(FacultySubjectMap).filter(
            FacultySubjectMap.subject_id.in_(dept_subject_ids)
        ).all()

        for item in mappings:
            self.preferences_by_subject[item.subject_id].append(item)

        self.rooms = self.db.query(TimetableRoom).order_by(TimetableRoom.name).all()
        self.room_map = {room.id: room for room in self.rooms}

        faculties = self.db.query(Faculty).all()
        self.faculty_map = {faculty.id: faculty for faculty in faculties}

    # ------------------------------------------------------------------
    # Delete previous timetable entries for these sections
    # ------------------------------------------------------------------
    def clear_existing_entries(self):
        section_ids = [s.id for s in self.sections]
        if not section_ids:
            return
        self.db.query(TimetableEntry).filter(
            TimetableEntry.section_id.in_(section_ids)
        ).delete(synchronize_session=False)

    # ------------------------------------------------------------------
    # MAIN ENTRY POINT
    # ------------------------------------------------------------------
    def generate(self):
        self.load_master_data()

        if not self.sections:
            return {
                "success": False,
                "sections_processed": 0,
                "errors": ["No sections found for given department and academic year"],
            }

        for section in self.sections:
            self._validate_section_setup(section)

        if self.errors:
            return {
                "success": False,
                "sections_processed": 0,
                "errors": self.errors,
            }

        self.clear_existing_entries()

        # Stage 1: Seed base slots (BLOCKED, LUNCH, THUB reserved)
        for section in self.sections:
            self._seed_section_base(section)

        for section in self.sections:
            self._init_section_free_periods(section)

        # Stage 2: Fixed subjects (FIP every day, PSA on specific day, etc.)
        for section in self.sections:
            self._place_fixed_subjects(section)

        # Stage 3: Multi-period constrained blocks (PSA=2 consecutive on Saturday)
        # Must run before labs so labs don't steal consecutive slots.
        for section in self.sections:
            self._place_constrained_multi_period_subjects(section)

        # Stage 4: Lab subjects (continuous blocks)
        for section in self.sections:
            self._place_lab_subjects(section)

        # Stage 5: Single-period constrained subjects (CRT, etc.)
        for section in self.sections:
            self._place_constrained_single_period_subjects(section)

        # Stage 6: Regular theory subjects
        # FIX: subjects sorted fewest-hours-first so low-hour subjects (IS=2h)
        # claim their days before high-hour subjects (CC=4h, ML=4h) flood the week.
        for section in self.sections:
            self._place_theory_subjects(section)

        # Stage 7: Fill any remaining free slots.
        # After all subject quotas are met, some days may still have empty teaching
        # slots. We mark those BLOCKED so the frontend shows them as intentionally
        # empty instead of a silent generator failure.
        for section in self.sections:
            self._fill_remaining_free_slots(section)

        if self.errors:
            self.db.rollback()
            return {
                "success": False,
                "sections_processed": len(self.sections),
                "errors": self.errors,
            }

        self.db.commit()

        return {
            "success": True,
            "sections_processed": len(self.sections),
            "errors": [],
        }

    # ------------------------------------------------------------------
    # Validation
    # ------------------------------------------------------------------
    def _validate_section_setup(self, section):
        subjects = self._subjects_for_section(section)
        if not subjects:
            self.errors.append(
                f"{section.name}: no subjects found for year={section.year} sem={section.semester}"
            )
            return

        feasibility_errors = validate_section_subject_feasibility(section, subjects)
        self.errors.extend([f"{section.name}: {msg}" for msg in feasibility_errors])

        for subject in subjects:
            needed = self._get_weekly_hours(section, subject)

            if needed <= 0 and not subject.is_fixed:
                continue

            if subject.subject_type == "THUB":
                continue

            if not subject.no_faculty_required and subject.id not in self.preferences_by_subject:
                self.errors.append(
                    f"{section.name}: no faculty mapped for subject '{subject.short_name}'. "
                    f"Please assign faculty via faculty-subject-map."
                )

            if (subject.requires_room_type == "LAB" or subject.is_lab) and not any(
                room.room_type == "LAB" for room in self.rooms
            ):
                self.errors.append(
                    f"{section.name}: no LAB rooms found for '{subject.short_name}'. "
                    f"Please add a lab room first."
                )

            if subject.requires_room_type == "CLASSROOM" and not any(
                room.room_type == "CLASSROOM" for room in self.rooms
            ):
                self.errors.append(
                    f"{section.name}: no CLASSROOM rooms found for '{subject.short_name}'. "
                    f"Please add a classroom first."
                )

    # ------------------------------------------------------------------
    # Stage 1: Seed base - mark BLOCKED, LUNCH, THUB slots
    # ------------------------------------------------------------------
    def _seed_section_base(self, section):
        for day in get_day_range(section):
            for period in range(section.total_periods_per_day):
                if not is_working_day(section, day):
                    self._create_entry(section.id, day, period, "BLOCKED", is_fixed=True)
                    continue

                if is_lunch_slot(section, period):
                    self._create_entry(section.id, day, period, "LUNCH", is_fixed=True)
                    continue

                if is_thub_reserved_slot(section, period):
                    self._create_entry(section.id, day, period, "THUB", is_fixed=True)

    def _init_section_free_periods(self, section):
        for day in get_day_range(section):
            if not is_working_day(section, day):
                continue
            for period in range(section.total_periods_per_day):
                if is_lunch_slot(section, period):
                    continue
                if is_thub_reserved_slot(section, period):
                    continue
                if self._slot_taken(section.id, day, period):
                    continue
                self.section_free_periods[(section.id, day)].add(period)

    # ------------------------------------------------------------------
    # Stage 2: Fixed subjects
    # ------------------------------------------------------------------
    def _place_fixed_subjects(self, section):
        for subject in self._subjects_for_section(section):
            if not subject.is_fixed:
                continue

            if getattr(subject, "fixed_every_working_day", False):
                target_days = get_working_days(section)
            elif subject.fixed_days:
                try:
                    target_days = [
                        int(x.strip()) for x in subject.fixed_days.split(",") if x.strip()
                    ]
                except Exception:
                    self.errors.append(
                        f"{section.name}: invalid fixed_days for '{subject.short_name}'"
                    )
                    continue
            elif subject.fixed_day is not None:
                target_days = [subject.fixed_day]
            else:
                self.errors.append(
                    f"{section.name}: fixed subject '{subject.short_name}' has no day info. "
                    f"Set fixed_day, fixed_days, or fixed_every_working_day=True."
                )
                continue

            if subject.fixed_start_period is None:
                self.errors.append(
                    f"{section.name}: fixed subject '{subject.short_name}' missing fixed_start_period."
                )
                continue

            span = max(1, subject.fixed_span)

            for day in target_days:
                if not is_working_day(section, day):
                    continue

                if not self._block_fits(section, day, subject.fixed_start_period, span, subject):
                    self.errors.append(
                        f"{section.name}: cannot place '{subject.short_name}' on day={day} "
                        f"period={subject.fixed_start_period} (slot already taken or blocked)."
                    )
                    continue

                faculty_id = None
                if not subject.no_faculty_required:
                    faculty_id = self._pick_faculty(
                        subject=subject,
                        day=day,
                        start_period=subject.fixed_start_period,
                        span=span,
                    )
                    if faculty_id is None:
                        self.errors.append(
                            f"{section.name}: no available faculty for fixed subject "
                            f"'{subject.short_name}' on day={day}."
                        )
                        continue

                room_id = self._pick_room(
                    section=section,
                    subject=subject,
                    day=day,
                    start_period=subject.fixed_start_period,
                    span=span,
                )
                if room_id is None and subject.requires_room_type not in [None, "NONE"]:
                    self.errors.append(
                        f"{section.name}: no room available for fixed subject "
                        f"'{subject.short_name}' on day={day}."
                    )
                    continue

                for offset in range(span):
                    self._create_entry(
                        section_id=section.id,
                        day=day,
                        period=subject.fixed_start_period + offset,
                        slot_type=subject.subject_type,
                        subject=subject,
                        faculty_id=faculty_id,
                        room_id=room_id,
                        is_fixed=True,
                        is_lab_continuation=(offset > 0),
                    )

    # ------------------------------------------------------------------
    # Stage 3: Multi-period constrained subjects (PSA etc.)
    # ------------------------------------------------------------------
    def _place_constrained_multi_period_subjects(self, section):
        subjects = [
            s
            for s in self._subjects_for_section(section)
            if (not s.is_lab)
            and (not s.is_fixed)
            and (s.allowed_days or s.allowed_periods)
            and s.subject_type not in ["THUB"]
            and (getattr(s, "min_continuous_periods", 1) or 1) > 1
        ]

        for subject in subjects:
            needed = self._get_weekly_hours(section, subject)
            if needed <= 0:
                continue

            min_cp = getattr(subject, "min_continuous_periods", 1) or 1
            placed_hours = 0
            blocks_needed = needed // min_cp
            leftover = needed % min_cp

            for _ in range(blocks_needed):
                if not self._place_continuous_block(section, subject, min_cp):
                    self.errors.append(
                        f"{section.name}: could not place {min_cp}-period block for "
                        f"'{subject.short_name}'. Check allowed_days/periods and available slots."
                    )
                    break
                placed_hours += min_cp

            if leftover > 0 and placed_hours == blocks_needed * min_cp:
                extra = self._place_repeated_single_periods(section, subject, leftover)
                placed_hours += extra
                if extra < leftover:
                    self.errors.append(
                        f"{section.name}: placed {placed_hours}/{needed} for "
                        f"'{subject.short_name}' (leftover single periods could not fit)."
                    )

    # ------------------------------------------------------------------
    # Stage 4: Lab subjects
    # ------------------------------------------------------------------
    def _place_lab_subjects(self, section):
        subjects = [
            s for s in self._subjects_for_section(section)
            if s.is_lab and not s.is_fixed
        ]

        for subject in subjects:
            remaining = self._get_weekly_hours(section, subject)
            if remaining <= 0:
                continue

            while remaining > 0:
                min_cp, max_cp = get_subject_continuous_span_for_section(subject, section)
                span = min(max_cp, remaining)
                span = max(min_cp, span)

                if span > remaining:
                    self.errors.append(
                        f"{section.name}: lab '{subject.short_name}' has {remaining} hours "
                        f"remaining but min block size is {min_cp}. "
                        f"Check weekly hours and continuous span for this section category."
                    )
                    break

                if not self._place_continuous_block(section, subject, span):
                    self.errors.append(
                        f"{section.name}: could not find a {span}-period slot for "
                        f"lab '{subject.short_name}'. Not enough free slots."
                    )
                    break

                remaining -= span

    # ------------------------------------------------------------------
    # Stage 5: Single-period constrained subjects
    # ------------------------------------------------------------------
    def _place_constrained_single_period_subjects(self, section):
        subjects = [
            s
            for s in self._subjects_for_section(section)
            if (not s.is_lab)
            and (not s.is_fixed)
            and (s.allowed_days or s.allowed_periods)
            and s.subject_type not in ["THUB"]
            and (getattr(s, "min_continuous_periods", 1) or 1) == 1
        ]

        for subject in subjects:
            needed = self._get_weekly_hours(section, subject)
            if needed <= 0:
                continue

            placed = self._place_repeated_single_periods(section, subject, needed)
            if placed < needed:
                self.errors.append(
                    f"{section.name}: placed {placed}/{needed} for "
                    f"constrained subject '{subject.short_name}'. "
                    f"Check allowed_days/periods and faculty availability."
                )

    # ------------------------------------------------------------------
    # Stage 6: Regular theory subjects
    #
    # FIX: Sort subjects by weekly hours ASCENDING (fewest hours first).
    # Low-hour subjects like IS (2h/week) must claim their slots before
    # high-hour subjects (CC=4h, ML=4h) flood every day and leave IS
    # squeezed onto one day that becomes under-filled.
    # ------------------------------------------------------------------
    def _place_theory_subjects(self, section):
        subjects = [
            s
            for s in self._subjects_for_section(section)
            if (not s.is_lab)
            and (not s.is_fixed)
            and (not s.allowed_days and not s.allowed_periods)
            and s.subject_type not in ["THUB"]
        ]

        # FIX: fewest weekly hours first so small subjects spread
        # to their best days before larger subjects fill them up.
        subjects_sorted = sorted(
            subjects,
            key=lambda s: self._get_weekly_hours(section, s)
        )

        for subject in subjects_sorted:
            needed = self._get_weekly_hours(section, subject)
            if needed <= 0:
                continue

            placed = self._place_repeated_single_periods(section, subject, needed)
            if placed < needed:
                self.errors.append(
                    f"{section.name}: placed {placed}/{needed} for "
                    f"theory subject '{subject.short_name}'."
                )

    # ------------------------------------------------------------------
    # Stage 7: Fill remaining free slots as BLOCKED
    #
    # After all subject quotas are satisfied, any teaching slot that is
    # still free is an unresolvable gap (no subject needs more hours).
    # We mark these BLOCKED so:
    #   - The frontend renders them explicitly (not as silent empty cells)
    #   - The operator can see the timetable is fully resolved
    #   - No slot is ever "just missing" from the schedule
    # ------------------------------------------------------------------
    def _fill_remaining_free_slots(self, section):
        for day in get_day_range(section):
            if not is_working_day(section, day):
                continue
            for period in range(section.total_periods_per_day):
                if is_lunch_slot(section, period):
                    continue
                if is_thub_reserved_slot(section, period):
                    continue
                if self._slot_taken(section.id, day, period):
                    continue
                # Slot is still free — mark it BLOCKED
                self._create_entry(
                    section_id=section.id,
                    day=day,
                    period=period,
                    slot_type="BLOCKED",
                    is_fixed=False,
                )

    # ------------------------------------------------------------------
    # Place N single-period slots spread across the week
    #
    # FIX: Primary score key is now -free_slots_on_day (negative so that
    # days with MORE free slots are scored lower = preferred first).
    # This ensures each theory subject actively spreads to the emptiest
    # available day instead of clustering on whichever day happens to
    # come first in iteration order.
    # ------------------------------------------------------------------
    def _place_repeated_single_periods(self, section, subject, needed):
        placed = 0

        for _ in range(needed):
            candidates = []

            for day in get_day_range(section):
                if not is_working_day(section, day):
                    continue

                same_day = self._same_subject_exists_on_day(section.id, subject.id, day)
                if same_day and not subject.allow_same_day_repeat:
                    continue

                # FIX: compute free-slot count for this day BEFORE placement
                free_count_on_day = len(self.section_free_periods[(section.id, day)])

                spacing_penalty = self._subject_spacing_penalty(section, subject, day)

                for period in range(section.total_periods_per_day):
                    if is_lunch_slot(section, period):
                        continue
                    if is_thub_reserved_slot(section, period):
                        continue
                    if not slot_allowed_by_subject(subject, day, period):
                        continue
                    if self._slot_taken(section.id, day, period):
                        continue

                    faculty_id = None
                    if not subject.no_faculty_required:
                        faculty_id = self._pick_faculty(subject, day, period, 1)
                        if faculty_id is None:
                            continue

                    room_id = self._pick_room(section, subject, day, period, 1)
                    if room_id is None and subject.requires_room_type not in [None, "NONE"]:
                        continue

                    clone_penalty = self._same_subject_same_slot_other_sections(
                        section=section,
                        subject=subject,
                        day=day,
                        period=period,
                    )

                    hole_penalty = self._hole_penalty(section, day, period)

                    # FIX: Primary key = -free_count_on_day
                    # More free slots on this day → lower score → chosen first.
                    # This distributes subjects to the emptiest days first,
                    # preventing one day from being left with 3 unfilled slots
                    # while every other day is full.
                    score = (
                        -free_count_on_day,          # PRIMARY: prefer emptiest day first
                        1 if same_day else 0,         # avoid same-day repeat if possible
                        spacing_penalty,              # avoid adjacent-day repeats
                        hole_penalty,                 # avoid creating isolated free gaps
                        self.section_day_load[(section.id, day)],  # balance load
                        clone_penalty,                # avoid same slot in parallel sections
                        abs(period - 3),              # prefer mid-day periods
                        period,                       # earlier period as tiebreaker
                    )

                    candidates.append((score, day, period, faculty_id, room_id))

            if not candidates:
                break

            candidates.sort(key=lambda item: item[0])
            _, day, period, faculty_id, room_id = candidates[0]

            self._create_entry(
                section_id=section.id,
                day=day,
                period=period,
                slot_type="THEORY" if subject.subject_type == "THEORY" else subject.subject_type,
                subject=subject,
                faculty_id=faculty_id,
                room_id=room_id,
                is_fixed=False,
            )

            placed += 1

        return placed

    # ------------------------------------------------------------------
    # Place a continuous block of `span` periods
    # ------------------------------------------------------------------
    def _place_continuous_block(self, section, subject, span):
        candidates = []

        for day in get_day_range(section):
            if not is_working_day(section, day):
                continue

            allowed_days_list = getattr(subject, "allowed_days", None)
            if allowed_days_list:
                parsed = parse_csv_ints(allowed_days_list)
                if parsed is not None and day not in parsed:
                    continue

            same_day = self._same_subject_exists_on_day(section.id, subject.id, day)
            spread_penalty = self._lab_day_spread_penalty(section, subject, day)

            prev_day, next_day = self._get_prev_next_working_days(section, day)
            nearby_lab_penalty = 0
            if prev_day is not None and self._section_has_lab_on_day(section.id, prev_day):
                nearby_lab_penalty += 2
            if next_day is not None and self._section_has_lab_on_day(section.id, next_day):
                nearby_lab_penalty += 2

            for start in range(0, section.total_periods_per_day - span + 1):
                if not self._block_fits(section, day, start, span, subject):
                    continue

                faculty_id = None if subject.no_faculty_required else self._pick_faculty(
                    subject, day, start, span
                )
                if not subject.no_faculty_required and faculty_id is None:
                    continue

                room_id = self._pick_room(section, subject, day, start, span)
                if room_id is None and subject.requires_room_type not in [None, "NONE"]:
                    continue

                after_lunch_bias = 0
                if section.category == "THUB":
                    after_lunch_bias = 0 if start > section.lunch_after_period else 1

                clone_penalty = self._same_subject_same_slot_other_sections(
                    section=section,
                    subject=subject,
                    day=day,
                    period=start,
                )

                block_hole_penalty = 0
                for offset in range(span):
                    block_hole_penalty += self._hole_penalty(section, day, start + offset)

                score = (
                    1 if same_day else 0,
                    spread_penalty,
                    nearby_lab_penalty,
                    self.section_day_load[(section.id, day)],
                    block_hole_penalty,
                    after_lunch_bias,
                    clone_penalty,
                    abs(start - 1),
                    start,
                )
                candidates.append((score, day, start, faculty_id, room_id))

        candidates.sort(key=lambda item: item[0])
        if not candidates:
            return False

        _, day, start, faculty_id, room_id = candidates[0]

        for offset in range(span):
            self._create_entry(
                section_id=section.id,
                day=day,
                period=start + offset,
                slot_type="LAB" if subject.subject_type == "LAB" else subject.subject_type,
                subject=subject,
                faculty_id=faculty_id,
                room_id=room_id,
                is_fixed=False,
                is_lab_continuation=(offset > 0),
            )

        return True

    # ------------------------------------------------------------------
    # Check if a continuous block of `span` periods fits
    # ------------------------------------------------------------------
    def _block_fits(self, section, day, start, span, subject):
        for period in range(start, start + span):
            if period >= section.total_periods_per_day:
                return False
            if not is_working_day(section, day):
                return False
            if is_lunch_slot(section, period):
                return False
            if is_thub_reserved_slot(section, period):
                return False
            if not slot_allowed_by_subject(subject, day, period):
                return False
            if self._slot_taken(section.id, day, period):
                return False
        return True

    # ------------------------------------------------------------------
    # Pick the best available faculty
    # ------------------------------------------------------------------
    def _pick_faculty(self, subject, day, start_period, span):
        preferences = self.preferences_by_subject.get(subject.id, [])
        candidates = []

        for pref in preferences:
            if subject.is_lab and not pref.can_handle_lab:
                continue

            daily_limit = pref.max_hours_per_day if pref.max_hours_per_day is not None else 7
            if self.faculty_day_hours[(pref.faculty_id, day)] + span > daily_limit:
                continue

            if pref.max_hours_per_week is not None:
                if self.faculty_week_hours[pref.faculty_id] + span > pref.max_hours_per_week:
                    continue

            clash = False
            for offset in range(span):
                if (pref.faculty_id, day, start_period + offset) in self.faculty_busy:
                    clash = True
                    break
            if clash:
                continue

            consecutive_penalty = 0
            if (pref.faculty_id, day, start_period - 1) in self.faculty_busy:
                consecutive_penalty += 1
            if (pref.faculty_id, day, start_period + span) in self.faculty_busy:
                consecutive_penalty += 1

            score = (
                0 if pref.is_primary else 1,
                pref.priority,
                self.faculty_day_hours[(pref.faculty_id, day)],
                self.faculty_week_hours[pref.faculty_id],
                consecutive_penalty,
                pref.faculty_id,
            )
            candidates.append((score, pref.faculty_id))

        if not candidates:
            return None

        candidates.sort(key=lambda item: item[0])
        return candidates[0][1]

    # ------------------------------------------------------------------
    # Pick the best available room
    # ------------------------------------------------------------------
    def _pick_room(self, section, subject, day, start_period, span):
        if subject.requires_room_type == "NONE":
            return None

        desired_type = subject.requires_room_type or ("LAB" if subject.is_lab else "CLASSROOM")

        preferred_names = []
        if subject.is_lab and subject.default_room_name:
            preferred_names.append(subject.default_room_name)
        if desired_type == "CLASSROOM" and section.classroom:
            preferred_names.append(section.classroom)
        if not subject.is_lab and subject.default_room_name:
            preferred_names.append(subject.default_room_name)

        candidate_rooms = [room for room in self.rooms if room.room_type == desired_type]

        def room_free(room):
            for offset in range(span):
                if (room.id, day, start_period + offset) in self.room_busy:
                    return False
            return True

        for pref_name in preferred_names:
            for room in candidate_rooms:
                if room.name == pref_name and room_free(room):
                    return room.id

        for room in candidate_rooms:
            if room_free(room):
                return room.id

        return None

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------
    def _subjects_for_section(self, section):
        all_subjects = self.subjects_by_key.get((section.year, section.semester), [])
        return [s for s in all_subjects if subject_applies_to_section(s, section)]

    def _same_subject_exists_on_day(self, section_id, subject_id, day):
        return (section_id, subject_id, day) in self.subject_day_tracker

    def _slot_taken(self, section_id, day, period):
        return (section_id, day, period) in self.section_busy

    def _get_prev_next_working_days(self, section, day):
        working_days = get_working_days(section)
        if day not in working_days:
            return None, None
        idx = working_days.index(day)
        prev_day = working_days[idx - 1] if idx > 0 else None
        next_day = working_days[idx + 1] if idx < len(working_days) - 1 else None
        return prev_day, next_day

    def _hole_penalty(self, section, day, period):
        free_periods = self.section_free_periods[(section.id, day)]
        remaining = set(free_periods)
        if period in remaining:
            remaining.remove(period)

        if not remaining:
            return 0

        sorted_periods = sorted(remaining)
        blocks = 1
        for i in range(1, len(sorted_periods)):
            if sorted_periods[i] != sorted_periods[i - 1] + 1:
                blocks += 1

        penalty = max(0, blocks - 1)

        for p in sorted_periods:
            left_busy = (p - 1) not in remaining
            right_busy = (p + 1) not in remaining
            if left_busy and right_busy:
                penalty += 2

        return penalty

    def _subject_spacing_penalty(self, section, subject, day):
        prev_day, next_day = self._get_prev_next_working_days(section, day)
        penalty = 0
        if prev_day is not None and self._same_subject_exists_on_day(section.id, subject.id, prev_day):
            penalty += 2
        if next_day is not None and self._same_subject_exists_on_day(section.id, subject.id, next_day):
            penalty += 2
        return penalty

    def _lab_day_spread_penalty(self, section, subject, day):
        penalty = 0
        existing_days_same_subject = self.section_lab_days[(section.id, subject.id)]
        if existing_days_same_subject:
            prev_day, next_day = self._get_prev_next_working_days(section, day)
            if day in existing_days_same_subject:
                penalty += 8
            if prev_day is not None and prev_day in existing_days_same_subject:
                penalty += 6
            if next_day is not None and next_day in existing_days_same_subject:
                penalty += 6

        labs_on_day = 0
        for (sec_id, subj_id), days in self.section_lab_days.items():
            if sec_id == section.id and day in days:
                labs_on_day += 1
        if labs_on_day > 0:
            penalty += 4 * labs_on_day

        all_lab_days = []
        for (sec_id, subj_id), days in self.section_lab_days.items():
            if sec_id == section.id:
                all_lab_days.extend(list(days))
        if all_lab_days:
            nearest_distance = min(abs(day - d) for d in all_lab_days)
            if nearest_distance == 0:
                penalty += 8
            elif nearest_distance == 1:
                penalty += 5
            elif nearest_distance == 2:
                penalty += 2

        return penalty

    def _section_has_lab_on_day(self, section_id, day):
        for (sec_id, subj_id), days in self.section_lab_days.items():
            if sec_id == section_id and day in days:
                return True
        return False

    def _same_subject_same_slot_other_sections(self, section, subject, day, period):
        total = self.subject_slot_tracker[
            (section.year, section.semester, subject.id, day, period)
        ]
        current_section_count = self.section_subject_slot_tracker[
            (section.id, subject.id, day, period)
        ]
        return total - current_section_count

    def _get_section(self, section_id):
        for s in self.sections:
            if s.id == section_id:
                return s
        return None

    def _create_entry(
        self,
        section_id,
        day,
        period,
        slot_type,
        subject=None,
        faculty_id=None,
        room_id=None,
        is_fixed=False,
        is_lab_continuation=False,
    ):
        entry = TimetableEntry(
            section_id=section_id,
            subject_id=subject.id if subject else None,
            faculty_id=faculty_id,
            room_id=room_id,
            day_index=day,
            period_index=period,
            slot_type=slot_type,
            is_fixed=is_fixed,
            is_lab_continuation=is_lab_continuation,
        )
        self.db.add(entry)

        self.section_busy.add((section_id, day, period))
        self.section_day_load[(section_id, day)] += 1

        if subject:
            self.subject_day_tracker.add((section_id, subject.id, day))
            self.subject_total_placed[(section_id, subject.id)] += 1
            self.section_subject_periods[(section_id, subject.id)].append((day, period))

            if subject.is_lab:
                self.section_lab_days[(section_id, subject.id)].add(day)

            section_obj = self._get_section(section_id)
            if section_obj is not None:
                self.subject_slot_tracker[
                    (section_obj.year, section_obj.semester, subject.id, day, period)
                ] += 1
                self.section_subject_slot_tracker[
                    (section_obj.id, subject.id, day, period)
                ] += 1

        if faculty_id:
            self.faculty_busy.add((faculty_id, day, period))
            self.faculty_day_hours[(faculty_id, day)] += 1
            self.faculty_week_hours[faculty_id] += 1

        if room_id:
            self.room_busy.add((room_id, day, period))

        free_key = (section_id, day)
        if period in self.section_free_periods[free_key]:
            self.section_free_periods[free_key].remove(period)