from datetime import datetime, timedelta
from typing import List, Optional


DAY_NAMES = ["MON", "TUE", "WED", "THU", "FRI", "SAT"]


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