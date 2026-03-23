import os
import re
import uuid
import pdfplumber
from datetime import datetime
from fastapi import HTTPException, UploadFile
from sqlalchemy.orm import Session
from app.holiday.holiday_models import Holiday


UPLOAD_DIR = "uploads/holiday_imports"


def ensure_upload_dir():
    os.makedirs(UPLOAD_DIR, exist_ok=True)


async def save_uploaded_pdf(pdf_file: UploadFile) -> str:
    if not pdf_file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are allowed.")

    ensure_upload_dir()

    unique_name = f"{uuid.uuid4().hex}_{pdf_file.filename}"
    file_path = os.path.join(UPLOAD_DIR, unique_name)

    try:
        contents = await pdf_file.read()
        with open(file_path, "wb") as f:
            f.write(contents)
    except Exception:
        raise HTTPException(status_code=500, detail="Failed to save uploaded PDF.")

    return file_path


def extract_text_from_pdf(file_path: str) -> str:
    try:
        full_text = []
        with pdfplumber.open(file_path) as pdf:
            for page in pdf.pages:
                text = page.extract_text()
                if text:
                    full_text.append(text)
        return "\n".join(full_text)
    except Exception:
        raise HTTPException(status_code=500, detail="Failed to extract text from PDF.")


def parse_holidays_from_text(text: str):
    extracted_holidays = []
    lines = [line.strip() for line in text.splitlines() if line.strip()]

    for line in lines:
        lower_line = line.lower()
        if "date" in lower_line and "day" in lower_line and "holiday" in lower_line:
            continue

        start_date = None
        end_date = None
        title = None

        # Example:
        # 14 January 2026 - 17 January 2026 Wednesday Sankranti
        match_range = re.match(
            r"^(\d{1,2}\s+[A-Za-z]+\s+\d{4})\s*[-–to]+\s*(\d{1,2}\s+[A-Za-z]+\s+\d{4})\s+(.+?)\s+(.+)$",
            line,
            re.IGNORECASE
        )

        # Example:
        # 01 January 2026 Thursday New Year
        match_single = re.match(
            r"^(\d{1,2}\s+[A-Za-z]+\s+\d{4})\s+([A-Za-z]+)\s+(.+)$",
            line,
            re.IGNORECASE
        )

        if match_range:
            raw_start = match_range.group(1).strip()
            raw_end = match_range.group(2).strip()
            title = match_range.group(4).strip()

            try:
                start_date = datetime.strptime(raw_start, "%d %B %Y").date()
                end_date = datetime.strptime(raw_end, "%d %B %Y").date()
            except ValueError:
                continue

        elif match_single:
            raw_date = match_single.group(1).strip()
            title = match_single.group(3).strip()

            try:
                start_date = datetime.strptime(raw_date, "%d %B %Y").date()
                end_date = start_date
            except ValueError:
                continue

        if start_date and end_date and title:
            extracted_holidays.append({
                "title": title,
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat(),
            })

    unique = {}
    for holiday in extracted_holidays:
        key = f"{holiday['title']}_{holiday['start_date']}_{holiday['end_date']}"
        unique[key] = holiday

    return list(unique.values())


async def preview_holidays_from_pdf(pdf_file: UploadFile):
    file_path = await save_uploaded_pdf(pdf_file)
    text = extract_text_from_pdf(file_path)
    holidays = parse_holidays_from_text(text)

    return {
        "message": "Holiday preview extracted successfully.",
        "file_path": file_path,
        "holidays": holidays
    }


def confirm_import_holidays(db: Session, holidays: list):
    if not holidays:
        raise HTTPException(status_code=400, detail="No holidays provided for import.")

    added_count = 0
    skipped_count = 0

    for item in holidays:
        try:
            start_date = datetime.strptime(item["start_date"], "%Y-%m-%d").date()
            end_date = datetime.strptime(item["end_date"], "%Y-%m-%d").date()
            title = item["title"].strip()

            existing = db.query(Holiday).filter(
                Holiday.start_date == start_date,
                Holiday.end_date == end_date,
                Holiday.title == title
            ).first()

            if existing:
                skipped_count += 1
                continue

            holiday = Holiday(
                title=title,
                start_date=start_date,
                end_date=end_date,
                description=None,
                holiday_type="CUSTOM",
                is_active=True
            )
            db.add(holiday)
            added_count += 1

        except Exception:
            skipped_count += 1
            continue

    db.commit()

    return {
        "message": "Holiday import completed successfully.",
        "added_count": added_count,
        "skipped_count": skipped_count
    }