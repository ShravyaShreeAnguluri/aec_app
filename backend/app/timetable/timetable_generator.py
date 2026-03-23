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

        # In-memory conflict tracking - keyed so all sections share faculty/room state
        self.section_busy = set()       # (section_id, day, period)
        self.faculty_busy = set()       # (faculty_id, day, period)
        self.room_busy = set()          # (room_id, day, period)

        self.faculty_day_hours = defaultdict(int)   # (faculty_id, day) -> count
        self.faculty_week_hours = defaultdict(int)  # faculty_id -> count

        self.subject_day_tracker = set()            # (section_id, subject_id, day)
        self.section_day_load = defaultdict(int)    # (section_id, day) -> count
        self.subject_total_placed = defaultdict(int) # (section_id, subject_id) -> count

    # ------------------------------------------------------------------
    # Weekly hours helper - respects THUB/NON_THUB per section
    # ------------------------------------------------------------------
    def _get_weekly_hours(self, section, subject):
        if section.category == "THUB":
            return (
                subject.weekly_hours_thub
                if subject.weekly_hours_thub is not None
                else subject.weekly_hours
            )
        if section.category == "NON_THUB":
            return (
                subject.weekly_hours_non_thub
                if subject.weekly_hours_non_thub is not None
                else subject.weekly_hours
            )
        return subject.weekly_hours

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

        # Load faculty-subject mappings
        # Note: load order doesn't matter because _pick_faculty re-sorts by score
        # Get all subject IDs for this department only
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
        self.db.commit()

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

        # FIX: Validate FIRST before deleting anything.
        # If there are fatal errors, old timetable is preserved.
        for section in self.sections:
            self._validate_section_setup(section)

        if self.errors:
            return {
                "success": False,
                "sections_processed": 0,
                "errors": self.errors,
            }

        # Only clear after validation passes
        self.clear_existing_entries()

        # Stage 1: Seed base slots (BLOCKED, LUNCH, THUB reserved)
        for section in self.sections:
            self._seed_section_base(section)

        # Stage 2: Place fixed subjects (FIP every day, PSA on specific day, etc.)
        for section in self.sections:
            self._place_fixed_subjects(section)

        # Stage 3: Place lab subjects (3-period continuous blocks)
        for section in self.sections:
            self._place_lab_subjects(section)

        # Stage 4: Place constrained subjects (CRT blocks, PSA with allowed_days, etc.)
        for section in self.sections:
            self._place_constrained_subjects(section)

        # Stage 5: Place regular theory subjects
        for section in self.sections:
            self._place_theory_subjects(section)

        self.db.commit()

        return {
            "success": len(self.errors) == 0,
            "sections_processed": len(self.sections),
            "errors": self.errors,
        }

    # ------------------------------------------------------------------
    # Validation - runs before any DB changes
    # ------------------------------------------------------------------
    def _validate_section_setup(self, section):
        subjects = self._subjects_for_section(section)
        if not subjects:
            self.errors.append(
                f"{section.name}: no subjects found for year={section.year} sem={section.semester}"
            )
            return

        for subject in subjects:
            needed = self._get_weekly_hours(section, subject)

            # Skip subjects with 0 hours that are also not fixed
            if needed <= 0 and not subject.is_fixed:
                continue

            # FIX: THUB type subjects are intentionally unlabeled blocks with no faculty.
            # Do not flag them as errors.
            if subject.subject_type == "THUB":
                continue

            # Check faculty mapping exists (skip if no faculty required)
            if not subject.no_faculty_required and subject.id not in self.preferences_by_subject:
                self.errors.append(
                    f"{section.name}: no faculty mapped for subject '{subject.short_name}'. "
                    f"Please assign faculty via faculty-subject-map."
                )

            # Check lab rooms exist if subject needs a lab
            if (subject.requires_room_type == "LAB" or subject.is_lab) and not any(
                room.room_type == "LAB" for room in self.rooms
            ):
                self.errors.append(
                    f"{section.name}: no LAB rooms found for '{subject.short_name}'. "
                    f"Please add a lab room first."
                )

            # Check classroom rooms exist if subject needs a classroom
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
        # FIX: Use get_day_range() instead of hardcoded range(6)
        # This correctly handles sections where working_days doesn't include day 5
        for day in get_day_range(section):
            for period in range(section.total_periods_per_day):
                if not is_working_day(section, day):
                    self._create_entry(section.id, day, period, "BLOCKED", is_fixed=True)
                    continue

                if is_lunch_slot(section, period):
                    self._create_entry(section.id, day, period, "LUNCH", is_fixed=True)
                    continue

                if is_thub_reserved_slot(section, period):
                    # THUB morning slots - no subject, no faculty, just marked T-Hub
                    self._create_entry(section.id, day, period, "THUB", is_fixed=True)

    # ------------------------------------------------------------------
    # Stage 2: Fixed subjects
    # FIX: handles fixed_every_working_day - no need to hardcode day numbers
    # ------------------------------------------------------------------
    def _place_fixed_subjects(self, section):
        for subject in self._subjects_for_section(section):
            if not subject.is_fixed:
                continue

            # Determine which days to place on
            if getattr(subject, "fixed_every_working_day", False):
                # e.g. FIP - place on every working day of this section
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
                # Skip non-working days (important for fixed_every_working_day)
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
    # Stage 3: Lab subjects (continuous blocks)
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
                span = min(subject.max_continuous_periods, remaining)
                span = max(subject.min_continuous_periods, span)

                if span > remaining:
                    # This shouldn't happen if schema validation passed (hours % min == 0)
                    self.errors.append(
                        f"{section.name}: lab '{subject.short_name}' has {remaining} hours "
                        f"remaining but min block size is {subject.min_continuous_periods}. "
                        f"Check weekly_hours is divisible by min_continuous_periods."
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
    # Stage 4: Constrained subjects
    # FIX: now handles both single-period AND multi-period constrained subjects
    # e.g. CRT-Soft Skills: min_continuous=2, allowed_days="4" (only Friday)
    # ------------------------------------------------------------------
    def _place_constrained_subjects(self, section):
        subjects = [
            s
            for s in self._subjects_for_section(section)
            if (not s.is_lab)
            and (not s.is_fixed)
            and (s.allowed_days or s.allowed_periods)
            and s.subject_type not in ["THUB"]
        ]

        for subject in subjects:
            needed = self._get_weekly_hours(section, subject)
            if needed <= 0:
                continue

            if subject.min_continuous_periods > 1:
                # Multi-period constrained block (e.g. CRT 2-period block)
                # Place as continuous blocks respecting allowed_days/periods
                placed_hours = 0
                blocks_needed = needed // subject.min_continuous_periods

                for _ in range(blocks_needed):
                    span = subject.min_continuous_periods
                    if not self._place_continuous_block(section, subject, span):
                        self.errors.append(
                            f"{section.name}: could not place constrained block for "
                            f"'{subject.short_name}' (span={span}). Check allowed_days/periods."
                        )
                        break
                    placed_hours += span

                if placed_hours < needed:
                    self.errors.append(
                        f"{section.name}: placed {placed_hours}/{needed} for '{subject.short_name}'."
                    )
            else:
                # Single-period constrained subject
                placed = self._place_repeated_single_periods(section, subject, needed)
                if placed < needed:
                    self.errors.append(
                        f"{section.name}: placed {placed}/{needed} for "
                        f"constrained subject '{subject.short_name}'."
                    )

    # ------------------------------------------------------------------
    # Stage 5: Regular theory subjects
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

        for subject in subjects:
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
    # Place N single-period slots spread across the week
    # Tries to spread evenly - avoids same day repeat unless allowed
    # ------------------------------------------------------------------
    def _place_repeated_single_periods(self, section, subject, needed):
        placed = 0

        for _ in range(needed):
            candidates = []

            # FIX: use get_day_range() not hardcoded range(6)
            for day in get_day_range(section):
                if not is_working_day(section, day):
                    continue

                same_day = self._same_subject_exists_on_day(section.id, subject.id, day)
                if same_day and not subject.allow_same_day_repeat:
                    continue

                for period in range(section.total_periods_per_day):
                    if is_lunch_slot(section, period):
                        continue
                    if is_thub_reserved_slot(section, period):
                        continue
                    if not slot_allowed_by_subject(subject, day, period):
                        continue
                    if self._slot_taken(section.id, day, period):
                        continue

                    faculty_id = None if subject.no_faculty_required else self._pick_faculty(
                        subject, day, period, 1
                    )
                    if not subject.no_faculty_required and faculty_id is None:
                        continue

                    room_id = self._pick_room(section, subject, day, period, 1)
                    if room_id is None and subject.requires_room_type not in [None, "NONE"]:
                        continue

                    # Score: prefer days where subject hasn't been placed yet,
                    # prefer days with fewer total classes (spread load),
                    # prefer earlier periods within a day
                    score = (
                        1 if same_day else 0,
                        self.section_day_load[(section.id, day)],
                        self.subject_total_placed[(section.id, subject.id)],
                        period,
                    )
                    candidates.append((score, day, period, faculty_id, room_id))

            candidates.sort(key=lambda item: item[0])
            if not candidates:
                break

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
    # Used for labs and multi-period constrained subjects
    # ------------------------------------------------------------------
    def _place_continuous_block(self, section, subject, span):
        candidates = []

        # FIX: use get_day_range() not hardcoded range(6)
        for day in get_day_range(section):
            if not is_working_day(section, day):
                continue

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

                # Prefer days with lighter load, prefer earlier start
                score = (
                    self.section_day_load[(section.id, day)],
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
    # Check if a continuous block of `span` periods fits starting at `start`
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
    # Pick the best available faculty for a subject at a given slot
    # Respects: clash check, daily limit, weekly limit, can_handle_lab
    # Prefers: primary > secondary, lower priority number, least loaded
    # ------------------------------------------------------------------
    def _pick_faculty(self, subject, day, start_period, span):
        preferences = self.preferences_by_subject.get(subject.id, [])
        candidates = []

        for pref in preferences:
            # Lab subjects only assigned to faculty who can handle labs
            if subject.is_lab and not pref.can_handle_lab:
                continue

            # Check daily hour limit (default 7 per college rule)
            daily_limit = pref.max_hours_per_day if pref.max_hours_per_day is not None else 7
            if self.faculty_day_hours[(pref.faculty_id, day)] + span > daily_limit:
                continue

            # Check weekly hour limit if set
            if pref.max_hours_per_week is not None:
                if self.faculty_week_hours[pref.faculty_id] + span > pref.max_hours_per_week:
                    continue

            # Check clash - faculty cannot be in two places at once
            clash = False
            for offset in range(span):
                if (pref.faculty_id, day, start_period + offset) in self.faculty_busy:
                    clash = True
                    break
            if clash:
                continue

            # Score: primary first, then lower priority number, then least loaded today, then least loaded this week
            score = (
                0 if pref.is_primary else 1,
                pref.priority,
                self.faculty_day_hours[(pref.faculty_id, day)],
                self.faculty_week_hours[pref.faculty_id],
                pref.faculty_id,  # tiebreaker
            )
            candidates.append((score, pref.faculty_id))

        if not candidates:
            return None

        candidates.sort(key=lambda item: item[0])
        return candidates[0][1]

    # ------------------------------------------------------------------
    # Pick the best available room for a subject
    # Prefers: subject default room > section's classroom > any free room
    # ------------------------------------------------------------------
    def _pick_room(self, section, subject, day, start_period, span):
        # Subject explicitly says no room needed
        if subject.requires_room_type == "NONE":
            return None

        desired_type = subject.requires_room_type or ("LAB" if subject.is_lab else "CLASSROOM")

        # Build preference list - more specific preferences first
        preferred_names = []
        if subject.default_room_name:
            preferred_names.append(subject.default_room_name)
        if section.classroom and desired_type == "CLASSROOM":
            preferred_names.append(section.classroom)

        candidate_rooms = [room for room in self.rooms if room.room_type == desired_type]

        def room_free(room):
            for offset in range(span):
                if (room.id, day, start_period + offset) in self.room_busy:
                    return False
            return True

        # Try preferred rooms first
        for pref_name in preferred_names:
            for room in candidate_rooms:
                if room.name == pref_name and room_free(room):
                    return room.id

        # Fall back to any free room of the right type
        for room in candidate_rooms:
            if room_free(room):
                return room.id

        return None

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------
    def _subjects_for_section(self, section):
        all_subjects = self.subjects_by_key.get((section.year, section.semester), [])
        return [
            s for s in all_subjects
            if s.applies_to_category is None
            or s.applies_to_category == section.category
        ]

    def _same_subject_exists_on_day(self, section_id, subject_id, day):
        return (section_id, subject_id, day) in self.subject_day_tracker

    def _slot_taken(self, section_id, day, period):
        return (section_id, day, period) in self.section_busy

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

        # Update in-memory state
        self.section_busy.add((section_id, day, period))
        self.section_day_load[(section_id, day)] += 1

        if subject:
            self.subject_day_tracker.add((section_id, subject.id, day))
            self.subject_total_placed[(section_id, subject.id)] += 1

        if faculty_id:
            self.faculty_busy.add((faculty_id, day, period))
            self.faculty_day_hours[(faculty_id, day)] += 1
            self.faculty_week_hours[faculty_id] += 1

        if room_id:
            self.room_busy.add((room_id, day, period))