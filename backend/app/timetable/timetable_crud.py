from sqlalchemy.orm import Session
from app.models import Faculty
from .timetable_models import (
    TimetableEntry,
    TimetableSection,
    TimetableSubject,
    TimetableRoom,
    FacultySubjectMap,
)


def get_section_schedule(db: Session, section_id: int):
    entries = (
        db.query(TimetableEntry)
        .filter(TimetableEntry.section_id == section_id)
        .order_by(TimetableEntry.day_index, TimetableEntry.period_index)
        .all()
    )

    subject_ids = {e.subject_id for e in entries if e.subject_id}
    faculty_ids = {e.faculty_id for e in entries if e.faculty_id}
    room_ids = {e.room_id for e in entries if e.room_id}

    subjects = {
        s.id: s
        for s in db.query(TimetableSubject).filter(TimetableSubject.id.in_(subject_ids)).all()
    } if subject_ids else {}

    faculties = {
        f.id: f
        for f in db.query(Faculty).filter(Faculty.id.in_(faculty_ids)).all()
    } if faculty_ids else {}

    rooms = {
        r.id: r
        for r in db.query(TimetableRoom).filter(TimetableRoom.id.in_(room_ids)).all()
    } if room_ids else {}

    result = []
    for e in entries:
        subject = subjects.get(e.subject_id)
        faculty = faculties.get(e.faculty_id)
        room = rooms.get(e.room_id)

        result.append(
            {
                "day_index": e.day_index,
                "period": e.period_index,
                "slot_type": e.slot_type,
                "subject": subject.name if subject else None,
                "subject_abbr": subject.short_name if subject else None,
                "faculty_name": faculty.name if faculty else None,
                "room": room.name if room else None,
                "is_lab_continuation": e.is_lab_continuation,
                "is_fixed": e.is_fixed,
            }
        )

    return result


def get_faculty_schedule(db: Session, faculty_public_id: str):
    faculty = db.query(Faculty).filter(Faculty.faculty_id == faculty_public_id).first()
    if not faculty:
        return None, []

    entries = (
        db.query(TimetableEntry)
        .filter(TimetableEntry.faculty_id == faculty.id)
        .order_by(TimetableEntry.day_index, TimetableEntry.period_index)
        .all()
    )

    section_ids = {e.section_id for e in entries if e.section_id}
    subject_ids = {e.subject_id for e in entries if e.subject_id}
    room_ids = {e.room_id for e in entries if e.room_id}

    sections = {
        s.id: s
        for s in db.query(TimetableSection).filter(TimetableSection.id.in_(section_ids)).all()
    } if section_ids else {}

    subjects = {
        s.id: s
        for s in db.query(TimetableSubject).filter(TimetableSubject.id.in_(subject_ids)).all()
    } if subject_ids else {}

    rooms = {
        r.id: r
        for r in db.query(TimetableRoom).filter(TimetableRoom.id.in_(room_ids)).all()
    } if room_ids else {}

    schedule = []
    for e in entries:
        section = sections.get(e.section_id)
        subject = subjects.get(e.subject_id)
        room = rooms.get(e.room_id)

        schedule.append(
            {
                "day_index": e.day_index,
                "period": e.period_index,
                "slot_type": e.slot_type,
                "section_name": section.name if section else None,
                "subject": subject.name if subject else None,
                "subject_abbr": subject.short_name if subject else None,
                "room": room.name if room else None,
                "is_fixed": e.is_fixed,
            }
        )

    return faculty, schedule


def get_faculty_subject_map_list(db: Session):
    rows = db.query(FacultySubjectMap).order_by(
        FacultySubjectMap.subject_id,
        FacultySubjectMap.priority,
    ).all()

    faculty_ids = {r.faculty_id for r in rows}
    subject_ids = {r.subject_id for r in rows}

    faculties = {
        f.id: f for f in db.query(Faculty).filter(Faculty.id.in_(faculty_ids)).all()
    } if faculty_ids else {}

    subjects = {
        s.id: s for s in db.query(TimetableSubject).filter(
            TimetableSubject.id.in_(subject_ids)
        ).all()
    } if subject_ids else {}

    result = []
    for r in rows:
        faculty = faculties.get(r.faculty_id)
        subject = subjects.get(r.subject_id)

        result.append(
            {
                "id": r.id,
                "faculty_id": r.faculty_id,
                "faculty_public_id": faculty.faculty_id if faculty else None,
                "faculty_name": faculty.name if faculty else None,
                "subject_id": r.subject_id,
                "subject_code": subject.code if subject else None,
                "subject_name": subject.name if subject else None,
                "subject_short_name": subject.short_name if subject else None,
                "priority": r.priority,
                "max_hours_per_week": r.max_hours_per_week,
                "max_hours_per_day": r.max_hours_per_day,
                "can_handle_lab": r.can_handle_lab,
                "is_primary": r.is_primary,
            }
        )

    return result