from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Faculty
from app.utils.auth_dependency import get_current_user

from .timetable_models import (
    TimetableSection,
    TimetableSubject,
    FacultySubjectMap,
    TimetableRoom,
)
from .timetable_schemas import (
    SectionCreate,
    SubjectCreate,
    FacultySubjectMapCreate,
    RoomCreate,
    GenerateTimetableRequest,
)
from .timetable_generator import TimetableGenerator
from .timetable_crud import get_faculty_schedule, get_section_schedule, get_faculty_subject_map_list
from .timetable_utils import build_period_labels


router = APIRouter(prefix="/timetable", tags=["Timetable"])


def _ensure_role(user):
    if user["role"] not in ["admin", "operator", "hod", "dean"]:
        raise HTTPException(status_code=403, detail="Not allowed")


@router.post("/sections")
def create_section(
    data: SectionCreate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    _ensure_role(user)

    obj = TimetableSection(
        department_id=data.department_id,
        name=data.name,
        year=data.year,
        semester=data.semester,
        academic_year=data.academic_year,
        category=data.category,
        classroom=data.classroom,
        total_periods_per_day=data.total_periods_per_day,
        working_days=data.working_days,
        lunch_after_period=data.lunch_after_period,
        lunch_label=data.lunch_label,
        thub_reserved_periods=data.thub_reserved_periods,
        slot_duration_minutes=data.slot_duration_minutes,
        lunch_duration_minutes=data.lunch_duration_minutes,
        start_time=data.start_time,          # NEW - operator sets this e.g. "09:30"
        created_by=user.get("faculty_id"),
    )

    try:
        db.add(obj)
        db.commit()
        db.refresh(obj)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail="Section already exists or invalid data")

    return {"message": "Section created", "id": obj.id}


@router.get("/sections")
def list_sections(
    department_id: int,
    academic_year: str,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    _ensure_role(user)

    rows = (
        db.query(TimetableSection)
        .filter(
            TimetableSection.department_id == department_id,
            TimetableSection.academic_year == academic_year,
        )
        .order_by(
            TimetableSection.year,
            TimetableSection.semester,
            TimetableSection.category,
            TimetableSection.name,
        )
        .all()
    )
    return rows


@router.post("/subjects")
def create_subject(
    data: SubjectCreate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    _ensure_role(user)

    # model_dump() automatically includes all fields including fixed_every_working_day
    obj = TimetableSubject(**data.model_dump())

    try:
        db.add(obj)
        db.commit()
        db.refresh(obj)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail="Subject already exists or invalid data")

    return {"message": "Subject created", "id": obj.id}


@router.get("/subjects")
def list_subjects(
    department_id: int,
    academic_year: str,
    year: int | None = None,
    semester: int | None = None,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    _ensure_role(user)

    query = db.query(TimetableSubject).filter(
        TimetableSubject.department_id == department_id,
        TimetableSubject.academic_year == academic_year,
    )

    if year is not None:
        query = query.filter(TimetableSubject.year == year)
    if semester is not None:
        query = query.filter(TimetableSubject.semester == semester)

    return query.order_by(
        TimetableSubject.year,
        TimetableSubject.semester,
        TimetableSubject.code,
    ).all()


@router.post("/faculty-subject-map")
def map_faculty_subject(
    data: FacultySubjectMapCreate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    _ensure_role(user)

    faculty = db.query(Faculty).filter(Faculty.faculty_id == data.faculty_public_id).first()
    if not faculty:
        raise HTTPException(
            status_code=404,
            detail=f"Faculty '{data.faculty_public_id}' not found"
        )

    subject = db.query(TimetableSubject).filter(TimetableSubject.id == data.subject_id).first()
    if not subject:
        raise HTTPException(
            status_code=404,
            detail=f"Subject id={data.subject_id} not found"
        )

    existing = db.query(FacultySubjectMap).filter(
        FacultySubjectMap.faculty_id == faculty.id,
        FacultySubjectMap.subject_id == data.subject_id,
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="This faculty is already mapped to this subject")

    obj = FacultySubjectMap(
        faculty_id=faculty.id,
        subject_id=data.subject_id,
        priority=data.priority,
        max_hours_per_week=data.max_hours_per_week,
        max_hours_per_day=data.max_hours_per_day,
        can_handle_lab=data.can_handle_lab,
        is_primary=data.is_primary,
    )

    db.add(obj)
    db.commit()
    db.refresh(obj)

    return {"message": "Faculty mapped", "id": obj.id}


@router.get("/faculty-subject-map")
def list_faculty_subject_maps(
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    _ensure_role(user)
    # Uses the proper helper that returns readable names, not just raw IDs
    return get_faculty_subject_map_list(db)


@router.post("/rooms")
def create_room(
    data: RoomCreate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    _ensure_role(user)

    existing = db.query(TimetableRoom).filter(TimetableRoom.name == data.name).first()
    if existing:
        raise HTTPException(status_code=400, detail="Room already exists")

    obj = TimetableRoom(**data.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)

    return {"message": "Room created", "id": obj.id}


@router.get("/rooms")
def list_rooms(
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    _ensure_role(user)
    return db.query(TimetableRoom).order_by(TimetableRoom.room_type, TimetableRoom.name).all()


@router.post("/generate/sync")
def generate_timetable(
    data: GenerateTimetableRequest,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    _ensure_role(user)

    generator = TimetableGenerator(
        db=db,
        department_id=data.department_id,
        academic_year=data.academic_year,
    )
    return generator.generate()


@router.get("/section/{section_id}")
def section_schedule(
    section_id: int,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    _ensure_role(user)

    section = db.query(TimetableSection).filter(TimetableSection.id == section_id).first()
    if not section:
        raise HTTPException(status_code=404, detail="Section not found")

    schedule = get_section_schedule(db, section_id)

    return {
        "section_id": section_id,
        "section_name": section.name,
        "year": section.year,
        "semester": section.semester,
        "category": section.category,
        "meta": {
            "working_days": section.working_days,
            "lunch_after_period": section.lunch_after_period,
            "total_periods_per_day": section.total_periods_per_day,
            "start_time": section.start_time,
            "period_labels": build_period_labels(section),
        },
        "schedule": schedule,
    }


@router.get("/faculty/{faculty_id}/schedule")
def faculty_schedule(
    faculty_id: str,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    _ensure_role(user)

    faculty, schedule = get_faculty_schedule(db, faculty_id)
    if faculty is None:
        raise HTTPException(status_code=404, detail="Faculty not found")

    return {
        "faculty_id": faculty.faculty_id,
        "faculty_name": faculty.name,
        "schedule": schedule,
    }