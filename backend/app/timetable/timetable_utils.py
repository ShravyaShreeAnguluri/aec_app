from datetime import datetime, timedelta
from typing import List, Optional, Tuple


DAY_NAMES = ["MON", "TUE", "WED", "THU", "FRI", "SAT"]


def _hours_reachable(hours: int, min_cp: int, max_cp: int) -> bool:
    """
    Check if `hours` can be formed by summing block sizes in [min_cp, max_cp].
    e.g. hours=3, min=2, max=3 → one block of 3 → True
    e.g. hours=5, min=3, max=3 → impossible → False
    e.g. hours=4, min=2, max=3 → two blocks of 2 → True
    """
    if hours <= 0 or min_cp <= 1:
        return True
    dp = [False] * (hours + 1)
    dp[0] = True
    for i in range(1, hours + 1):
        for block in range(min_cp, max_cp + 1):
            if i >= block and dp[i - block]:
                dp[i] = True
                break
    return dp[hours]


def parse_csv_ints(value: Optional[str]) -> Optional[List[int]]:
    """Parse a CSV string of integers. Returns None if value is empty."""
    if value is None or str(value).strip() == "":
        return None

    result: List[int] = []
    for item in str(value).split(","):
        item = item.strip()
        if not item:
            continue
        try:
            result.append(int(item))
        except ValueError:
            pass
    return result


def get_working_days(section) -> List[int]:
    """Return sorted list of working day indexes for this section."""
    days = parse_csv_ints(getattr(section, "working_days", None))
    if days is None:
        return list(range(6))  # Mon-Sat default
    return sorted(days)


def get_day_range(section) -> range:
    """
    Return a range covering all possible day indexes for this section.
    e.g. working_days="0,1,2,3,4" -> range(5)
         working_days="0,1,2,3,4,5" -> range(6)
    This is used in loops - we iterate this range and check is_working_day().
    """
    days = parse_csv_ints(getattr(section, "working_days", None))
    if not days:
        return range(6)
    return range(max(days) + 1)


def is_working_day(section, day_index: int) -> bool:
    allowed = parse_csv_ints(getattr(section, "working_days", None))
    if allowed is None:
        return True
    return day_index in allowed


def is_lunch_slot(section, period_index: int) -> bool:
    return period_index == getattr(section, "lunch_after_period", 3)


def is_thub_reserved_slot(section, period_index: int) -> bool:
    if getattr(section, "category", None) != "THUB":
        return False
    reserved = parse_csv_ints(getattr(section, "thub_reserved_periods", None))
    return reserved is not None and period_index in reserved


def slot_allowed_by_subject(subject, day_index: int, period_index: int) -> bool:
    allowed_days = parse_csv_ints(getattr(subject, "allowed_days", None))
    allowed_periods = parse_csv_ints(getattr(subject, "allowed_periods", None))

    if allowed_days is not None and day_index not in allowed_days:
        return False
    if allowed_periods is not None and period_index not in allowed_periods:
        return False
    return True

def validate_section_config(section) -> List[str]:
    """
    Validate section-level timetable settings.
    Returns list of error messages. Empty list means valid.
    """
    errors: List[str] = []

    total_periods = getattr(section, "total_periods_per_day", 0) or 0
    lunch_after = getattr(section, "lunch_after_period", None)
    slot_duration = getattr(section, "slot_duration_minutes", 0) or 0
    lunch_duration = getattr(section, "lunch_duration_minutes", 0) or 0
    start_time = getattr(section, "start_time", None)

    if total_periods <= 0:
        errors.append("total_periods_per_day must be greater than 0")

    if lunch_after is None or lunch_after < 0 or lunch_after >= total_periods:
        errors.append("lunch_after_period must be between 0 and total_periods_per_day - 1")

    working_days = parse_csv_ints(getattr(section, "working_days", None))
    if working_days is not None:
        invalid_days = [d for d in working_days if d < 0 or d > 5]
        if invalid_days:
            errors.append("working_days must contain only values from 0 to 5")

    reserved = parse_csv_ints(getattr(section, "thub_reserved_periods", None))
    if reserved is not None:
        invalid_periods = [p for p in reserved if p < 0 or p >= total_periods]
        if invalid_periods:
            errors.append("thub_reserved_periods contains invalid period indexes")
        if lunch_after in reserved:
            errors.append("lunch_after_period cannot also be in thub_reserved_periods")

    if slot_duration <= 0:
        errors.append("slot_duration_minutes must be greater than 0")

    if lunch_duration <= 0:
        errors.append("lunch_duration_minutes must be greater than 0")

    if start_time:
        try:
            h, m = str(start_time).split(":")
            hh = int(h)
            mm = int(m)
            if not (0 <= hh <= 23 and 0 <= mm <= 59):
                errors.append("start_time must be a valid HH:MM value")
        except Exception:
            errors.append("start_time must be in HH:MM format")

    return errors

def validate_subject_config(subject) -> List[str]:
    """
    Validate subject-level configuration.
    Returns list of error messages. Empty list means valid.
    """
    errors: List[str] = []

    is_lab = bool(getattr(subject, "is_lab", False))
    is_fixed = bool(getattr(subject, "is_fixed", False))

    min_cp = getattr(subject, "min_continuous_periods", 1) or 1
    max_cp = getattr(subject, "max_continuous_periods", 1) or 1
    fixed_span = getattr(subject, "fixed_span", 1) or 1

    weekly_hours = getattr(subject, "weekly_hours", 0) or 0
    weekly_hours_thub = getattr(subject, "weekly_hours_thub", 0) or 0
    weekly_hours_non_thub = getattr(subject, "weekly_hours_non_thub", 0) or 0

    if min_cp <= 0 or max_cp <= 0:
        errors.append("min_continuous_periods and max_continuous_periods must be greater than 0")

    if min_cp > max_cp:
        errors.append("min_continuous_periods cannot be greater than max_continuous_periods")

    if fixed_span <= 0:
        errors.append("fixed_span must be greater than 0")

    if weekly_hours < 0 or weekly_hours_thub < 0 or weekly_hours_non_thub < 0:
        errors.append("weekly hours cannot be negative")

    if is_lab:
        min_cp_thub = getattr(subject, "min_continuous_periods_thub", None)
        min_cp_non_thub = getattr(subject, "min_continuous_periods_non_thub", None)

        has_valid_common = min_cp >= 2
        has_valid_thub = min_cp_thub is not None and min_cp_thub >= 2
        has_valid_non_thub = min_cp_non_thub is not None and min_cp_non_thub >= 2

        if not (has_valid_common or has_valid_thub or has_valid_non_thub):
            errors.append(
                "lab subjects must have a valid continuous span: "
                "common min_continuous_periods >= 2 or category-wise THUB/NON_THUB min >= 2"
            )

        if getattr(subject, "requires_room_type", None) not in ("LAB", "lab"):
            errors.append("lab subjects should have requires_room_type='LAB'")

    if is_fixed:
        fixed_start_period = getattr(subject, "fixed_start_period", None)
        fixed_day = getattr(subject, "fixed_day", None)
        fixed_days = getattr(subject, "fixed_days", None)
        fixed_every = bool(getattr(subject, "fixed_every_working_day", False))

        if fixed_start_period is None or fixed_start_period < 0:
            errors.append("fixed subjects must have a valid fixed_start_period")

        if not fixed_every and fixed_day is None and not fixed_days:
            errors.append(
                "fixed subjects must define fixed_day, fixed_days, or fixed_every_working_day=True"
            )

        if fixed_every and fixed_day is not None:
            errors.append("fixed_every_working_day=True should not be combined with fixed_day")

    allowed_days = parse_csv_ints(getattr(subject, "allowed_days", None))
    if allowed_days is not None:
        invalid_days = [d for d in allowed_days if d < 0 or d > 5]
        if invalid_days:
            errors.append("allowed_days must contain only values from 0 to 5")

    allowed_periods = parse_csv_ints(getattr(subject, "allowed_periods", None))
    if allowed_periods is not None:
        invalid_periods = [p for p in allowed_periods if p < 0]
        if invalid_periods:
            errors.append("allowed_periods must contain only non-negative values")

    applies_to = getattr(subject, "applies_to_category", None)
    if applies_to not in (None, "", "THUB", "NON_THUB"):
        errors.append("applies_to_category must be NULL, THUB, or NON_THUB")

    return errors

def get_subject_weekly_hours_for_section(subject, section) -> int:
    """
    Return the effective weekly hours for a subject based on section category.
    """
    category = getattr(section, "category", None)

    if category == "THUB":
        value = getattr(subject, "weekly_hours_thub", None)
        if value is not None:
            return int(value or 0)

    if category == "NON_THUB":
        value = getattr(subject, "weekly_hours_non_thub", None)
        if value is not None:
            return int(value or 0)

    return int(getattr(subject, "weekly_hours", 0) or 0)

def get_subject_continuous_span_for_section(subject, section) -> Tuple[int, int]:
    """
    Return effective (min_cp, max_cp) based on section category.
    Falls back to common min/max if category-specific values are not set.
    """
    category = getattr(section, "category", None)

    if category == "THUB":
        min_cp = getattr(subject, "min_continuous_periods_thub", None)
        max_cp = getattr(subject, "max_continuous_periods_thub", None)
        return (
            int(min_cp if min_cp is not None else getattr(subject, "min_continuous_periods", 1) or 1),
            int(max_cp if max_cp is not None else getattr(subject, "max_continuous_periods", 1) or 1),
        )

    if category == "NON_THUB":
        min_cp = getattr(subject, "min_continuous_periods_non_thub", None)
        max_cp = getattr(subject, "max_continuous_periods_non_thub", None)
        return (
            int(min_cp if min_cp is not None else getattr(subject, "min_continuous_periods", 1) or 1),
            int(max_cp if max_cp is not None else getattr(subject, "max_continuous_periods", 1) or 1),
        )

    return (
        int(getattr(subject, "min_continuous_periods", 1) or 1),
        int(getattr(subject, "max_continuous_periods", 1) or 1),
    )

def subject_applies_to_section(subject, section) -> bool:
    """
    Check whether a subject applies to this section category.
    """
    applies_to = getattr(subject, "applies_to_category", None)
    if applies_to in (None, ""):
        return True
    return applies_to == getattr(section, "category", None)

def get_subject_fixed_days(subject, section) -> List[int]:
    """
    Expand subject fixed-day config into actual working day indexes.
    """
    if not getattr(subject, "is_fixed", False):
        return []

    if getattr(subject, "fixed_every_working_day", False):
        return get_working_days(section)

    fixed_day = getattr(subject, "fixed_day", None)
    if fixed_day is not None:
        return [fixed_day]

    fixed_days = parse_csv_ints(getattr(subject, "fixed_days", None))
    if fixed_days is not None:
        return fixed_days

    return []

def count_available_teaching_slots(section) -> int:
    """
    Count usable weekly teaching slots after excluding lunch and THUB reserved slots.
    """
    total_periods = getattr(section, "total_periods_per_day", 8)
    working_days = get_working_days(section)

    usable = 0
    for day_index in working_days:
        for period_index in range(total_periods):
            if is_lunch_slot(section, period_index):
                continue
            if is_thub_reserved_slot(section, period_index):
                continue
            usable += 1

    return usable

def count_fixed_required_slots(subject, section) -> int:
    """
    Count total weekly slots consumed by a fixed subject in a section.
    """
    if not getattr(subject, "is_fixed", False):
        return 0

    days = get_subject_fixed_days(subject, section)
    span = getattr(subject, "fixed_span", 1) or 1
    return len(days) * span

def validate_section_subject_feasibility(section, subjects) -> List[str]:
    """
    Validate whether all applicable subject hours can fit into this section's usable slots.
    """
    errors: List[str] = []

    available_slots = count_available_teaching_slots(section)
    required_slots = 0

    for subject in subjects:
        if not subject_applies_to_section(subject, section):
            continue

        hours = get_subject_weekly_hours_for_section(subject, section)
        if hours <= 0:
            continue

        if getattr(subject, "is_fixed", False):
            fixed_needed = count_fixed_required_slots(subject, section)
            if fixed_needed != hours:
                errors.append(
                    f"{getattr(subject, 'name', getattr(subject, 'short_name', 'Subject'))}: fixed slots ({fixed_needed}) "
                    f"do not match weekly hours ({hours})"
                )
            required_slots += fixed_needed
        else:
            required_slots += hours

        if getattr(subject, "is_lab", False):
            min_cp, max_cp = get_subject_continuous_span_for_section(subject, section)
            if not _hours_reachable(hours, min_cp, max_cp):
                errors.append(
                    f"{getattr(subject, 'name', getattr(subject, 'short_name', 'Subject'))}: weekly hours ({hours}) "
                    f"cannot be achieved using lab blocks of [{min_cp}..{max_cp}] periods"
                )

    if required_slots > available_slots:
        errors.append(
            f"Total required slots ({required_slots}) exceed available teaching slots ({available_slots}) "
            f"for section {getattr(section, 'section_name', '')}"
        )

    return errors

def build_period_labels(section) -> List[str]:
    """
    Build human-readable time labels for each period slot.
    Uses section.start_time (set by operator) instead of hardcoded 9:30 AM.
    """
    labels: List[str] = []

    total_slots = getattr(section, "total_periods_per_day", 8)
    lunch_after = getattr(section, "lunch_after_period", 3)
    lunch_duration = getattr(section, "lunch_duration_minutes", 60)
    slot_duration = getattr(section, "slot_duration_minutes", 50)
    lunch_label = getattr(section, "lunch_label", "LUNCH") or "LUNCH"

    # Use operator-set start_time, fall back to 09:30 only if not set
    start_time_str = getattr(section, "start_time", None) or "09:30"
    try:
        h, m = start_time_str.split(":")
        current = datetime(2000, 1, 1, int(h), int(m))
    except Exception:
        current = datetime(2000, 1, 1, 9, 30)

    teaching_no = 1

    for slot_index in range(total_slots):
        if slot_index == lunch_after:
            end = current + timedelta(minutes=lunch_duration)
            labels.append(
                f"{lunch_label} "
                f"{current.strftime('%I:%M %p')} - {end.strftime('%I:%M %p')}"
            )
            current = end
        else:
            end = current + timedelta(minutes=slot_duration)
            labels.append(
                f"P{teaching_no} {current.strftime('%I:%M %p')} - {end.strftime('%I:%M %p')}"
            )
            current = end
            teaching_no += 1

    return labels