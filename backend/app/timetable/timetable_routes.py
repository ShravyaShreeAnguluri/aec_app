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
from .timetable_crud import (
    get_faculty_schedule,
    get_section_schedule,
    get_faculty_subject_map_list,
    validate_setup_for_department,
)
from .timetable_utils import (
    build_period_labels,
    validate_section_config,
    validate_subject_config,
)


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

    validation_errors = validate_section_config(obj)
    if validation_errors:
        raise HTTPException(
            status_code=400,
            detail={
                "message": "Section validation failed",
                "errors": validation_errors,
            },
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

    validation_errors = validate_subject_config(obj)
    if validation_errors:
        raise HTTPException(
            status_code=400,
            detail={
                "message": "Subject validation failed",
                "errors": validation_errors,
            },
        )

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


@router.put("/subjects/{subject_id}")
def update_subject(
    subject_id: int,
    data: SubjectCreate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    """
    Update any field on an existing subject.
    Use this to fix scheduling config (allowed_days, min_continuous_periods,
    is_fixed, weekly_hours, etc.) without touching the database directly.
    """
    _ensure_role(user)

    obj = db.query(TimetableSubject).filter(TimetableSubject.id == subject_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Subject not found")

    for field, value in data.model_dump().items():
        setattr(obj, field, value)

    validation_errors = validate_subject_config(obj)
    if validation_errors:
        raise HTTPException(
            status_code=400,
            detail={"message": "Subject validation failed", "errors": validation_errors},
        )

    try:
        db.commit()
        db.refresh(obj)
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail="Update failed — check for duplicate code in same dept/year/sem/ay.",
        )

    return {"message": "Subject updated", "id": obj.id}


@router.delete("/subjects/{subject_id}")
def delete_subject(
    subject_id: int,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    """
    Delete a subject and its faculty mappings.
    Will fail if timetable entries exist — clear timetable first.
    """
    _ensure_role(user)

    obj = db.query(TimetableSubject).filter(TimetableSubject.id == subject_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Subject not found")

    db.query(FacultySubjectMap).filter(
        FacultySubjectMap.subject_id == subject_id
    ).delete(synchronize_session=False)

    try:
        db.delete(obj)
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail="Cannot delete — timetable entries exist. Clear timetable first.",
        )

    return {"message": "Subject deleted", "id": subject_id}


@router.put("/sections/{section_id}")
def update_section(
    section_id: int,
    data: SectionCreate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    """
    Update an existing section (fix lunch timings, working_days, thub_reserved_periods etc.).
    """
    _ensure_role(user)

    obj = db.query(TimetableSection).filter(TimetableSection.id == section_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Section not found")

    for field, value in data.model_dump().items():
        setattr(obj, field, value)

    validation_errors = validate_section_config(obj)
    if validation_errors:
        raise HTTPException(
            status_code=400,
            detail={"message": "Section validation failed", "errors": validation_errors},
        )

    try:
        db.commit()
        db.refresh(obj)
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail="Update failed — duplicate section name in same dept/ay.",
        )

    return {"message": "Section updated", "id": obj.id}


@router.delete("/sections/{section_id}")
def delete_section(
    section_id: int,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    """
    Delete a section and all its timetable entries.
    """
    _ensure_role(user)

    obj = db.query(TimetableSection).filter(TimetableSection.id == section_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Section not found")

    from .timetable_models import TimetableEntry
    db.query(TimetableEntry).filter(
        TimetableEntry.section_id == section_id
    ).delete(synchronize_session=False)

    db.delete(obj)
    db.commit()

    return {"message": "Section deleted", "id": section_id}


@router.delete("/faculty-subject-map/{map_id}")
def delete_faculty_subject_map(
    map_id: int,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    """
    Remove a faculty-subject mapping (e.g. wrong faculty assigned).
    """
    _ensure_role(user)

    obj = db.query(FacultySubjectMap).filter(FacultySubjectMap.id == map_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Mapping not found")

    db.delete(obj)
    db.commit()

    return {"message": "Mapping deleted", "id": map_id}


@router.put("/faculty-subject-map/{map_id}")
def update_faculty_subject_map(
    map_id: int,
    data: FacultySubjectMapCreate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    """
    Update priority, max_hours_per_week, max_hours_per_day, can_handle_lab, is_primary
    for an existing faculty-subject mapping.
    """
    _ensure_role(user)

    obj = db.query(FacultySubjectMap).filter(FacultySubjectMap.id == map_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Mapping not found")

    obj.priority = data.priority
    obj.max_hours_per_week = data.max_hours_per_week
    obj.max_hours_per_day = data.max_hours_per_day
    obj.can_handle_lab = data.can_handle_lab
    obj.is_primary = data.is_primary

    db.commit()
    db.refresh(obj)

    return {"message": "Mapping updated", "id": obj.id}


@router.delete("/rooms/{room_id}")
def delete_room(
    room_id: int,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    """
    Delete a room. Fails if timetable entries reference it.
    """
    _ensure_role(user)

    obj = db.query(TimetableRoom).filter(TimetableRoom.id == room_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Room not found")

    try:
        db.delete(obj)
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail="Cannot delete room — timetable entries reference it. Clear timetable first.",
        )

    return {"message": "Room deleted", "id": room_id}


@router.put("/rooms/{room_id}")
def update_room(
    room_id: int,
    data: RoomCreate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    """
    Update room name, type, or capacity.
    """
    _ensure_role(user)

    obj = db.query(TimetableRoom).filter(TimetableRoom.id == room_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Room not found")

    existing = db.query(TimetableRoom).filter(
        TimetableRoom.name == data.name,
        TimetableRoom.id != room_id,
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Another room with this name already exists")

    for field, value in data.model_dump().items():
        setattr(obj, field, value)

    try:
        db.commit()
        db.refresh(obj)
    except Exception:
        db.rollback()
        raise HTTPException(status_code=400, detail="Update failed")

    return {"message": "Room updated", "id": obj.id}


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

    if subject.no_faculty_required:
        raise HTTPException(
            status_code=400,
            detail="This subject is marked as no_faculty_required, so faculty mapping is not needed",
        )

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

@router.get("/validate-setup")
def validate_setup(
    department_id: int,
    academic_year: str,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    _ensure_role(user)

    return validate_setup_for_department(
        db=db,
        department_id=department_id,
        academic_year=academic_year,
    )
    
@router.post("/generate/sync")
def generate_timetable(
    data: GenerateTimetableRequest,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    _ensure_role(user)

    setup_check = validate_setup_for_department(
        db=db,
        department_id=data.department_id,
        academic_year=data.academic_year,
    )

    if not setup_check["ok"]:
        raise HTTPException(
            status_code=400,
            detail={
                "message": "Timetable setup validation failed. Fix the issues before generation.",
                "setup_check": setup_check,
            },
        )

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