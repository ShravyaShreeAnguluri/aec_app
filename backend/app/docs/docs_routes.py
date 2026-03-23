from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from sqlalchemy import or_
from typing import Optional
from datetime import datetime
import uuid
import pathlib
import mimetypes

from app.database import get_db
from app.docs.docs_models import Subject, Document, Certificate

router = APIRouter(prefix="/api", tags=["Faculty Docs"])

UPLOAD_DIR = pathlib.Path("uploads")
CERT_DIR = pathlib.Path("certificates")
UPLOAD_DIR.mkdir(exist_ok=True)
CERT_DIR.mkdir(exist_ok=True)


def get_file_type(filename: str) -> str:
    ext = pathlib.Path(filename).suffix.lower().lstrip(".")
    allowed = ["pdf", "ppt", "pptx", "doc", "docx", "xls", "xlsx", "jpg", "jpeg", "png"]
    return ext if ext in allowed else "other"


@router.get("/health")
def health():
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat()}


# =====================================================
# SUBJECTS
# =====================================================

@router.get("/subjects")
def get_subjects(
    year: Optional[int] = None,
    department: Optional[str] = None,
    db: Session = Depends(get_db)
):
    query = db.query(Subject)

    if year is not None:
        query = query.filter(Subject.year == year)
    if department:
        query = query.filter(Subject.department == department)

    subjects = query.order_by(Subject.department, Subject.year, Subject.name).all()

    return {
        "success": True,
        "data": [
            {
                "id": s.id,
                "department": s.department,
                "name": s.name,
                "code": s.code,
                "year": s.year,
                "semester": s.semester,
                "description": s.description,
                "createdAt": s.created_at,
            }
            for s in subjects
        ],
    }


@router.get("/subjects/departments/list")
def get_departments(db: Session = Depends(get_db)):
    rows = db.query(Subject.department).distinct().all()
    departments = sorted([r[0] for r in rows if r[0]])
    return {"success": True, "data": departments}


@router.get("/subjects/year/{year}")
def get_subjects_by_year(
    year: int,
    department: Optional[str] = None,
    db: Session = Depends(get_db)
):
    query = db.query(Subject).filter(Subject.year == year)

    if department:
        query = query.filter(Subject.department == department)

    subjects = query.order_by(Subject.name).all()

    return {
        "success": True,
        "data": [
            {
                "id": s.id,
                "department": s.department,
                "name": s.name,
                "code": s.code,
                "year": s.year,
                "semester": s.semester,
                "description": s.description,
                "createdAt": s.created_at,
            }
            for s in subjects
        ],
    }


@router.post("/subjects")
def add_subject(body: dict, db: Session = Depends(get_db)):
    existing = db.query(Subject).filter(Subject.code == body.get("code")).first()
    if existing:
        raise HTTPException(status_code=400, detail="Subject code already exists")

    subject = Subject(
        department=body.get("department"),
        name=body.get("name"),
        code=body.get("code"),
        year=body.get("year"),
        semester=body.get("semester"),
        description=body.get("description", ""),
        created_at=datetime.utcnow().isoformat(),
    )

    db.add(subject)
    db.commit()
    db.refresh(subject)

    return {
        "success": True,
        "data": {
            "id": subject.id,
            "department": subject.department,
            "name": subject.name,
            "code": subject.code,
            "year": subject.year,
            "semester": subject.semester,
            "description": subject.description,
            "createdAt": subject.created_at,
        },
    }


@router.post("/subjects")
def add_subject(body: dict, db: Session = Depends(get_db)):
    department = body.get("department")
    name = body.get("name")
    code = body.get("code")
    year = body.get("year")
    semester = body.get("semester")
    description = body.get("description", "")

    if not department:
        raise HTTPException(status_code=400, detail="Department is required")
    if not name:
        raise HTTPException(status_code=400, detail="Name is required")
    if not code:
        raise HTTPException(status_code=400, detail="Code is required")
    if year is None:
        raise HTTPException(status_code=400, detail="Year is required")
    if semester is None:
        raise HTTPException(status_code=400, detail="Semester is required")

    existing = db.query(Subject).filter(Subject.code == code).first()
    if existing:
        raise HTTPException(status_code=400, detail="Subject code already exists")

    subject = Subject(
        department=department,
        name=name,
        code=code,
        year=int(year),
        semester=int(semester),
        description=description,
        created_at=datetime.utcnow().isoformat(),
    )

    db.add(subject)
    db.commit()
    db.refresh(subject)

    return {
        "success": True,
        "data": {
            "id": subject.id,
            "department": subject.department,
            "name": subject.name,
            "code": subject.code,
            "year": subject.year,
            "semester": subject.semester,
            "description": subject.description,
            "createdAt": subject.created_at,
        },
    }


@router.post("/subjects/seed")
def seed_subjects(db: Session = Depends(get_db)):
    defaults = [
        {"department": "CSE", "name": "Engineering Mathematics I", "code": "MA101", "year": 1, "semester": 1},
        {"department": "CSE", "name": "Physics for Engineers", "code": "PH101", "year": 1, "semester": 1},
        {"department": "CSE", "name": "Introduction to Programming", "code": "CSE101", "year": 1, "semester": 1},
        {"department": "CSE", "name": "Digital Logic Design", "code": "CSE102", "year": 1, "semester": 2},
        {"department": "CSE", "name": "Data Structures", "code": "CSE201", "year": 2, "semester": 3},
        {"department": "CSE", "name": "Object Oriented Programming", "code": "CSE202", "year": 2, "semester": 3},
        {"department": "CSE", "name": "Database Management Systems", "code": "CSE203", "year": 2, "semester": 4},
        {"department": "CSE", "name": "Computer Networks", "code": "CSE301", "year": 3, "semester": 5},
        {"department": "CSE", "name": "Operating Systems", "code": "CSE302", "year": 3, "semester": 5},
        {"department": "CSE", "name": "Software Engineering", "code": "CSE303", "year": 3, "semester": 6},
        {"department": "CSE", "name": "Machine Learning", "code": "CSE401", "year": 4, "semester": 7},
        {"department": "CSE", "name": "Cloud Computing", "code": "CSE402", "year": 4, "semester": 7},
        {"department": "CSE", "name": "Information Security", "code": "CSE404", "year": 4, "semester": 8},
        {"department": "ECE", "name": "Basic Electronics", "code": "ECE101", "year": 1, "semester": 1},
        {"department": "ECE", "name": "Circuit Theory", "code": "ECE201", "year": 2, "semester": 3},
        {"department": "ECE", "name": "Digital Electronics", "code": "ECE202", "year": 2, "semester": 3},
        {"department": "ECE", "name": "Signals & Systems", "code": "ECE203", "year": 2, "semester": 4},
        {"department": "ECE", "name": "Microprocessors", "code": "ECE301", "year": 3, "semester": 5},
        {"department": "ECE", "name": "VLSI Design", "code": "ECE302", "year": 3, "semester": 6},
        {"department": "ECE", "name": "Embedded Systems", "code": "ECE401", "year": 4, "semester": 7},
        {"department": "ECE", "name": "IoT & Applications", "code": "ECE402", "year": 4, "semester": 8},
        {"department": "MECH", "name": "Engineering Mechanics", "code": "ME101", "year": 1, "semester": 1},
        {"department": "MECH", "name": "Engineering Drawing", "code": "ME102", "year": 1, "semester": 2},
        {"department": "MECH", "name": "Thermodynamics", "code": "ME201", "year": 2, "semester": 3},
        {"department": "MECH", "name": "Fluid Mechanics", "code": "ME202", "year": 2, "semester": 4},
        {"department": "MECH", "name": "Machine Design", "code": "ME301", "year": 3, "semester": 5},
        {"department": "MECH", "name": "Heat Transfer", "code": "ME302", "year": 3, "semester": 6},
        {"department": "MECH", "name": "CAD/CAM", "code": "ME401", "year": 4, "semester": 7},
        {"department": "CIVIL", "name": "Building Materials", "code": "CV101", "year": 1, "semester": 1},
        {"department": "CIVIL", "name": "Surveying", "code": "CV201", "year": 2, "semester": 3},
        {"department": "CIVIL", "name": "Structural Analysis", "code": "CV202", "year": 2, "semester": 4},
        {"department": "CIVIL", "name": "Geotechnical Engineering", "code": "CV301", "year": 3, "semester": 5},
        {"department": "CIVIL", "name": "Water Resources", "code": "CV401", "year": 4, "semester": 7},
        {"department": "IT", "name": "Introduction to Programming", "code": "IT101", "year": 1, "semester": 1},
        {"department": "IT", "name": "Data Structures", "code": "IT201", "year": 2, "semester": 3},
        {"department": "IT", "name": "Web Development", "code": "IT301", "year": 3, "semester": 5},
        {"department": "IT", "name": "Mobile App Development", "code": "IT302", "year": 3, "semester": 6},
        {"department": "IT", "name": "Cloud & DevOps", "code": "IT401", "year": 4, "semester": 7},
    ]

    seeded = 0
    for item in defaults:
        exists = db.query(Subject).filter(Subject.code == item["code"]).first()
        if not exists:
            subject = Subject(
                department=item["department"],
                name=item["name"],
                code=item["code"],
                year=item["year"],
                semester=item["semester"],
                description="",
                created_at=datetime.utcnow().isoformat(),
            )
            db.add(subject)
            seeded += 1

    db.commit()
    return {"success": True, "message": f"Seeded {seeded} subjects"}


# =====================================================
# DOCUMENTS
# =====================================================

@router.get("/documents")
def get_documents(
    year: Optional[int] = None,
    department: Optional[str] = None,
    category: Optional[str] = None,
    search: Optional[str] = None,
    uploadedBy: Optional[str] = None,
    db: Session = Depends(get_db)
):
    query = db.query(Document)

    if year is not None:
        query = query.filter(Document.year == year)
    if department:
        query = query.filter(Document.department == department)
    if category:
        query = query.filter(Document.category == category)
    if uploadedBy:
        query = query.filter(Document.uploaded_by.ilike(uploadedBy))

    if search:
        pattern = f"%{search}%"
        query = query.filter(
            or_(
                Document.title.ilike(pattern),
                Document.subject_name.ilike(pattern),
                Document.department.ilike(pattern),
            )
        )

    documents = query.order_by(Document.id.desc()).all()

    return {
        "success": True,
        "count": len(documents),
        "data": [
            {
                "id": d.id,
                "title": d.title,
                "description": d.description,
                "fileName": d.file_name,
                "originalName": d.original_name,
                "fileType": d.file_type,
                "fileSize": d.file_size,
                "filePath": d.file_path,
                "year": d.year,
                "department": d.department,
                "subject": d.subject,
                "subjectName": d.subject_name,
                "category": d.category,
                "uploadedBy": d.uploaded_by,
                "downloadCount": d.download_count,
                "createdAt": d.created_at,
            }
            for d in documents
        ],
    }


@router.get("/documents/stats/summary")
def get_document_stats(db: Session = Depends(get_db)):
    documents = db.query(Document).all()

    by_year = {}
    by_dept = {}

    for d in documents:
        if d.year not in by_year:
            by_year[d.year] = {"_id": d.year, "count": 0, "totalSize": 0}
        by_year[d.year]["count"] += 1
        by_year[d.year]["totalSize"] += d.file_size or 0

        if d.department not in by_dept:
            by_dept[d.department] = {"_id": d.department, "count": 0}
        by_dept[d.department]["count"] += 1

    return {
        "success": True,
        "data": {
            "byYear": sorted(by_year.values(), key=lambda x: x["_id"]),
            "byDept": sorted(by_dept.values(), key=lambda x: x["_id"]),
            "total": len(documents),
        },
    }


@router.get("/documents/{doc_id}")
def get_document(doc_id: int, db: Session = Depends(get_db)):
    doc = db.query(Document).filter(Document.id == doc_id).first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    return {
        "success": True,
        "data": {
            "id": doc.id,
            "title": doc.title,
            "description": doc.description,
            "fileName": doc.file_name,
            "originalName": doc.original_name,
            "fileType": doc.file_type,
            "fileSize": doc.file_size,
            "filePath": doc.file_path,
            "year": doc.year,
            "department": doc.department,
            "subject": doc.subject,
            "subjectName": doc.subject_name,
            "category": doc.category,
            "uploadedBy": doc.uploaded_by,
            "downloadCount": doc.download_count,
            "createdAt": doc.created_at,
        },
    }


@router.post("/documents/upload")
async def upload_document(
    file: UploadFile = File(...),
    title: str = Form(...),
    description: str = Form(""),
    year: int = Form(...),
    department: str = Form(...),
    subject: str = Form(...),
    subjectName: str = Form(...),
    category: str = Form("Lecture Notes"),
    uploadedBy: str = Form("Faculty"),
    db: Session = Depends(get_db)
):
    ext = pathlib.Path(file.filename).suffix
    fname = f"{uuid.uuid4()}{ext}"

    dept_dir = UPLOAD_DIR / f"year_{year}" / department.replace(" ", "_")
    dept_dir.mkdir(parents=True, exist_ok=True)

    fpath = dept_dir / fname
    contents = await file.read()
    fpath.write_bytes(contents)

    doc = Document(
        title=title,
        description=description,
        file_name=fname,
        original_name=file.filename,
        file_type=get_file_type(file.filename),
        file_size=len(contents),
        file_path=f"/uploads/year_{year}/{department.replace(' ', '_')}/{fname}",
        year=year,
        department=department,
        subject=subject,
        subject_name=subjectName,
        category=category,
        uploaded_by=uploadedBy,
        download_count=0,
        created_at=datetime.utcnow().isoformat(),
    )

    db.add(doc)
    db.commit()
    db.refresh(doc)

    return {
        "success": True,
        "message": "Uploaded successfully",
        "data": {
            "id": doc.id,
            "title": doc.title,
            "description": doc.description,
            "fileName": doc.file_name,
            "originalName": doc.original_name,
            "fileType": doc.file_type,
            "fileSize": doc.file_size,
            "filePath": doc.file_path,
            "year": doc.year,
            "department": doc.department,
            "subject": doc.subject,
            "subjectName": doc.subject_name,
            "category": doc.category,
            "uploadedBy": doc.uploaded_by,
            "downloadCount": doc.download_count,
            "createdAt": doc.created_at,
        },
    }


@router.put("/documents/{doc_id}")
def update_document(doc_id: int, body: dict, db: Session = Depends(get_db)):
    doc = db.query(Document).filter(Document.id == doc_id).first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    doc.title = body.get("title", doc.title)
    doc.description = body.get("description", doc.description)
    doc.category = body.get("category", doc.category)

    db.commit()
    db.refresh(doc)

    return {
        "success": True,
        "data": {
            "id": doc.id,
            "title": doc.title,
            "description": doc.description,
            "category": doc.category,
        },
    }


@router.delete("/documents/{doc_id}")
def delete_document(doc_id: int, db: Session = Depends(get_db)):
    doc = db.query(Document).filter(Document.id == doc_id).first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    fpath = UPLOAD_DIR / f"year_{doc.year}" / doc.department.replace(" ", "_") / doc.file_name
    if fpath.exists():
        fpath.unlink()

    db.delete(doc)
    db.commit()

    return {"success": True, "message": "Deleted"}


@router.get("/documents/{doc_id}/download")
def download_document(doc_id: int, db: Session = Depends(get_db)):
    doc = db.query(Document).filter(Document.id == doc_id).first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    file_path = UPLOAD_DIR / f"year_{doc.year}" / doc.department.replace(" ", "_") / doc.file_name
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found on disk")

    doc.download_count += 1
    db.commit()

    mime, _ = mimetypes.guess_type(str(file_path))
    return FileResponse(
        path=str(file_path),
        filename=doc.original_name,
        media_type=mime or "application/octet-stream",
        headers={"ngrok-skip-browser-warning": "true"},
    )


@router.get("/documents/{doc_id}/view")
def view_document(doc_id: int, db: Session = Depends(get_db)):
    doc = db.query(Document).filter(Document.id == doc_id).first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    file_path = UPLOAD_DIR / f"year_{doc.year}" / doc.department.replace(" ", "_") / doc.file_name
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found on disk")

    mime, _ = mimetypes.guess_type(str(file_path))
    return FileResponse(
        path=str(file_path),
        filename=doc.original_name,
        media_type=mime or "application/octet-stream",
        headers={
            "Content-Disposition": "inline",
            "ngrok-skip-browser-warning": "true",
        },
    )


# =====================================================
# CERTIFICATES
# =====================================================

@router.get("/certificates")
def get_certificates(
    type: Optional[str] = None,
    department: Optional[str] = None,
    facultyName: Optional[str] = None,
    db: Session = Depends(get_db)
):
    query = db.query(Certificate)

    if type:
        query = query.filter(Certificate.type == type)
    if department:
        query = query.filter(Certificate.department == department)
    if facultyName:
        query = query.filter(Certificate.faculty_name.ilike(facultyName))

    items = query.order_by(Certificate.id.desc()).all()

    return {
        "success": True,
        "count": len(items),
        "data": [
            {
                "id": c.id,
                "title": c.title,
                "facultyName": c.faculty_name,
                "department": c.department,
                "type": c.type,
                "issuedBy": c.issued_by,
                "issueDate": c.issue_date,
                "fileName": c.file_name,
                "originalName": c.original_name,
                "fileType": c.file_type,
                "fileSize": c.file_size,
                "filePath": c.file_path,
                "createdAt": c.created_at,
            }
            for c in items
        ],
    }


@router.post("/certificates/upload")
async def upload_certificate(
    file: UploadFile = File(...),
    title: str = Form(...),
    facultyName: str = Form(...),
    department: str = Form(...),
    type: str = Form(...),
    issuedBy: str = Form(...),
    issueDate: str = Form(...),
    db: Session = Depends(get_db)
):
    allowed = ["Faculty Achievement", "Training & Workshop"]
    if type not in allowed:
        raise HTTPException(status_code=400, detail=f"type must be one of: {allowed}")

    ext = pathlib.Path(file.filename).suffix
    fname = f"{uuid.uuid4()}{ext}"

    dest = CERT_DIR / type.replace(" ", "_") / department.replace(" ", "_")
    dest.mkdir(parents=True, exist_ok=True)

    contents = await file.read()
    (dest / fname).write_bytes(contents)

    cert = Certificate(
        title=title,
        faculty_name=facultyName,
        department=department,
        type=type,
        issued_by=issuedBy,
        issue_date=issueDate,
        file_name=fname,
        original_name=file.filename,
        file_type=get_file_type(file.filename),
        file_size=len(contents),
        file_path=f"/certificates/{type.replace(' ', '_')}/{department.replace(' ', '_')}/{fname}",
        created_at=datetime.utcnow().isoformat(),
    )

    db.add(cert)
    db.commit()
    db.refresh(cert)

    return {
        "success": True,
        "message": "Certificate uploaded",
        "data": {
            "id": cert.id,
            "title": cert.title,
            "facultyName": cert.faculty_name,
            "department": cert.department,
            "type": cert.type,
            "issuedBy": cert.issued_by,
            "issueDate": cert.issue_date,
            "fileName": cert.file_name,
            "originalName": cert.original_name,
            "fileType": cert.file_type,
            "fileSize": cert.file_size,
            "filePath": cert.file_path,
            "createdAt": cert.created_at,
        },
    }


@router.get("/certificates/{cert_id}/download")
def download_certificate(cert_id: int, db: Session = Depends(get_db)):
    cert = db.query(Certificate).filter(Certificate.id == cert_id).first()
    if not cert:
        raise HTTPException(status_code=404, detail="Certificate not found")

    file_path = CERT_DIR / cert.type.replace(" ", "_") / cert.department.replace(" ", "_") / cert.file_name
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found on disk")

    mime, _ = mimetypes.guess_type(str(file_path))
    return FileResponse(
        path=str(file_path),
        filename=cert.original_name,
        media_type=mime or "application/octet-stream",
        headers={"ngrok-skip-browser-warning": "true"},
    )


@router.delete("/certificates/{cert_id}")
def delete_certificate(cert_id: int, db: Session = Depends(get_db)):
    cert = db.query(Certificate).filter(Certificate.id == cert_id).first()
    if not cert:
        raise HTTPException(status_code=404, detail="Certificate not found")

    fpath = CERT_DIR / cert.type.replace(" ", "_") / cert.department.replace(" ", "_") / cert.file_name
    if fpath.exists():
        fpath.unlink()

    db.delete(cert)
    db.commit()

    return {"success": True, "message": "Deleted"}

@router.get("/certificates/{cert_id}/view")
def view_certificate(cert_id: int, db: Session = Depends(get_db)):
    cert = db.query(Certificate).filter(Certificate.id == cert_id).first()
    if not cert:
        raise HTTPException(status_code=404, detail="Certificate not found")

    file_path = CERT_DIR / cert.type.replace(" ", "_") / cert.department.replace(" ", "_") / cert.file_name
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found on disk")

    mime, _ = mimetypes.guess_type(str(file_path))
    return FileResponse(
        path=str(file_path),
        filename=cert.original_name,
        media_type=mime or "application/octet-stream",
        headers={
            "Content-Disposition": "inline",
            "ngrok-skip-browser-warning": "true",
        },
    )