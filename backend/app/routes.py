from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.orm import Session
from .database import get_db
from .models import Faculty
from . import schemas, crud, models
from .face_utils import extract_face_embedding, compare_faces
import base64
import pickle
from datetime import datetime, timedelta, time, date
from app.utils.otp import generate_otp, otp_expiry_time
from app.utils.email import send_otp_email
from app.schemas import FacultyCreate  
from sqlalchemy.exc import IntegrityError
import math
from app.utils.reset_token import generate_reset_token, reset_token_expiry
from app.utils.email import send_reset_email
from fastapi.responses import RedirectResponse
from pydantic import ValidationError
from app.utils.jwt_handler import create_access_token
from app.utils.auth_dependency import get_current_user
from app.leave.leave_routes import router as leave_router
from app.auth import verify_password, hash_password
from app.holiday.holiday_service import validate_attendance_not_holiday
from app.holiday.holiday_routes import router as holiday_router
from app.holiday.holiday_service import validate_leave_range_has_working_day
from .schemas import LoginRequest, OTPRequest, OTPVerifyRequest, FacultyCreate
from app.leave.leave_models import Leave
from app.timetable.timetable_routes import router as timetable_router
from app.admin.admin_routes import router as admin_router

router = APIRouter()
router.include_router(leave_router)
router.include_router(holiday_router)
router.include_router(timetable_router)
router.include_router(admin_router)

# =====================================================
# REGISTER FACULTY
# =====================================================
@router.get("/seed-departments")
def seed_departments(db: Session = Depends(get_db)):
    from app.models import Department

    depts = ["CSE", "ECE", "EEE", "MECH", "CIVIL"]

    for d in depts:
        db.add(Department(name=d))

    db.commit()
    return {"message": "Departments added"}
from sqlalchemy import text

@router.get("/db-test")
def db_test(db: Session = Depends(get_db)):
    try:
        result = db.execute(text("SELECT 1"))
        return {"message": "DB connected"}
    except Exception as e:
        return {"error": str(e)}
@router.post("/register", response_model=schemas.FacultyResponse)
async def register_faculty(
    faculty_id: str = Form(...),
    name: str = Form(...),
    department: str = Form(...),
    email: str = Form(...),
    password: str = Form(...),
    designation: str = Form(None),
    qualification: str = Form(None),
    face_image: UploadFile = File(...),
    profile_image: UploadFile = File(None), 
    db: Session = Depends(get_db)
):

     # Read face image
    face_bytes = await face_image.read()
    if not face_bytes:
        raise HTTPException(status_code=400, detail="Face image required")

    # Extract face embedding
    embedding = extract_face_embedding(face_bytes)
    if embedding is None:
        raise HTTPException(status_code=400, detail="Face not detected properly")

    embedding_bytes = pickle.dumps(embedding)

    profile_bytes = None
    if profile_image is not None:
        contents = await profile_image.read()
        if contents:
            profile_bytes = contents

    role = "faculty"
    # ✅ Prevent duplicate face registration
    all_users = db.query(Faculty).all()

    for user in all_users:
        if user.face_embedding:
            stored_embedding = pickle.loads(user.face_embedding)
            if compare_faces(embedding, stored_embedding):
                raise HTTPException(
                    status_code=400,
                    detail="This face is already registered"
                )

    try:
        faculty_data = schemas.FacultyCreate(
            faculty_id=faculty_id,
            name=name,
            department=department,
            email=email,
            password=password,
            role=role,
            designation=designation,
            qualification=qualification
        )

    except Exception as e:
        # Any pydantic validation error (e.g., weak password, invalid email)
        errors = [f"{err['loc'][0].replace('_',' ').title()}: {err['msg']}" for err in e.errors()]
        raise HTTPException(status_code=400, detail="; ".join(errors))
    
    # ---------- Create Faculty (UPDATED TO INCLUDE ROLE & PROFILE) ----------
    try:
        new_user = Faculty(
            faculty_id=faculty_id,
            name=name,
            department=department,
            email=email,
            password=hash_password(password),
            role=role,
            designation=designation,
            qualification=qualification,
            face_embedding=embedding_bytes,
            profile_image=profile_bytes
        )

        db.add(new_user)
        db.commit()
        db.refresh(new_user)

        return new_user
    
    except IntegrityError as e:
        db.rollback()  # Important after DB errors
        # Check the exact field causing duplication
        msg = str(e.orig)
        if "faculty_email_key" in msg:
            raise HTTPException(status_code=400, detail="Email already exists")
        elif "faculty_faculty_id_key" in msg:
            raise HTTPException(status_code=400, detail="Faculty ID already exists")
        else:
            raise HTTPException(status_code=400, detail="Duplicate entry")

@router.get("/departments", response_model=list[schemas.DepartmentResponse])
def get_departments(db: Session = Depends(get_db)):
    departments = db.query(models.Department).all()
    return departments

# =====================================================
# VERIFY FACE (GENERAL PURPOSE)
# =====================================================

@router.post("/verify-face")
async def verify_face(
    email: str = Form(...),
    face_image: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    faculty = crud.get_faculty_by_email(db, email)

    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")

    image_bytes = await face_image.read()

    if not image_bytes:
        raise HTTPException(status_code=400, detail="Face image is required")

    live_embedding = extract_face_embedding(image_bytes)

    if live_embedding is None:
        raise HTTPException(
            status_code=400,
            detail="Face not detected properly"
        )

    stored_embedding = pickle.loads(faculty.face_embedding)

    is_match = compare_faces(live_embedding, stored_embedding)

    if is_match:
        return {"status": "success", "message": "Face matched"}
    else:
        return {"status": "failed", "message": "Face not matched"}


# =====================================================
# LOGIN WITH PASSWORD
# =====================================================

@router.post("/login")
def login(data: schemas.LoginRequest, db: Session = Depends(get_db)):
    email = data.email.strip().lower()
    user = db.query(Faculty).filter(Faculty.email == email).first()

    if not user or not verify_password(data.password, user.password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    return {
        "message": "Login successful",
        "faculty_id": user.faculty_id,
        "name": user.name
    }

# =====================================================
# OTP LOGIN REQUEST
# =====================================================

@router.post("/login-request")
def login_request(data: schemas.OTPRequest, db: Session = Depends(get_db)):

    email = data.email.strip().lower()
    user = db.query(Faculty).filter(Faculty.email == email).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    otp = generate_otp()
    user.otp = otp
    user.otp_expiry = otp_expiry_time()

    db.commit()

    send_otp_email(user.email, otp)

    return {"message": "OTP sent to your email"}

# =====================================================
# VERIFY OTP
# =====================================================

@router.post("/verify-otp")
def verify_otp(data: OTPVerifyRequest, db: Session = Depends(get_db)):
    email = data.email.strip().lower()
    user = db.query(Faculty).filter(Faculty.email == email).first()

    if not user or not user.otp or not user.otp_expiry:
        raise HTTPException(status_code=400, detail="OTP not generated")

    if datetime.utcnow() > user.otp_expiry:
        raise HTTPException(status_code=400, detail="OTP expired")

    if user.otp != data.otp:
        raise HTTPException(status_code=401, detail="Invalid OTP")

    user.otp = None
    user.otp_expiry = None
    db.commit()

    token = create_access_token({
        "faculty_id": user.faculty_id,
        "email": user.email,
        "role": user.role,
        "department": user.department,
    })

    return {
        "message": "Login successful",
        "access_token": token,
        "faculty_id": user.faculty_id,
        "name": user.name,
        "email": user.email,
        "department": user.department,
        "designation": user.designation,
        "qualification": user.qualification,
        "role": user.role,
        "profile_image": base64.b64encode(user.profile_image).decode() if user.profile_image else None
    }

@router.post("/change-password")
def change_password(
    data: schemas.ChangePasswordRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    user = db.query(Faculty).filter(
        Faculty.email == current_user["email"]
    ).first()

    if not verify_password(data.current_password, user.password):
        raise HTTPException(status_code=400, detail="Incorrect current password")

    user.password = hash_password(data.new_password)
    db.commit()

    return {"message": "Password updated successfully"}

# ATTENDANCE TIME RULES

CLOCK_IN_START = time(9, 0)
CLOCK_IN_END = time(9, 30)

HALF_DAY_MORNING_CLOCK_IN_START = time(12, 0)
HALF_DAY_MORNING_CLOCK_IN_END = time(12, 30)

HALF_DAY_AFTERNOON_CLOCK_OUT_START = time(12, 0)
HALF_DAY_AFTERNOON_CLOCK_OUT_END = time(12, 30)

IDEAL_CLOCK_OUT_START = time(16, 20)
IDEAL_CLOCK_OUT_END = time(16, 30)

AUTO_ABSENT_TIME = time(16, 30)
MAX_MONTHLY_PERMISSIONS = 3

# =====================================================
# COLLEGE LOCATION SETTINGS
# =====================================================

COLLEGE_LAT = 16.986119
COLLEGE_LON = 81.796158
ALLOWED_RADIUS_METERS = 500  # 100 meters

# =====================================================
# HELPER FUNCTION: DISTANCE CALCULATION (HAVERSINE)
# =====================================================

def calculate_distance(lat1, lon1, lat2, lon2):
    """
    Calculates distance between two GPS points in meters
    """
    R = 6371000  # Earth radius in meters

    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)

    a = math.sin(dphi / 2) ** 2 + \
        math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2

    return R * (2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)))

def get_today_approved_leave(db: Session, faculty_id: str):
    today = date.today()
    return db.query(Leave).filter(
        Leave.faculty_id == faculty_id,
        Leave.status == "APPROVED",
        Leave.start_date <= today,
        Leave.end_date >= today
    ).first()

# =====================================================
# ATTENDANCE CLOCK-IN (FINAL LOGIC)
# =====================================================

@router.post("/attendance/clock-in")
async def clock_in_attendance(
    latitude: float = Form(...),
    longitude: float = Form(...),
    face_image: UploadFile = File(...),
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    faculty = crud.get_faculty_by_email(db, current_user["email"])
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")

    validate_attendance_not_holiday(db, date.today())

    now = datetime.now()
    current_time = now.time()

    today_leave = get_today_approved_leave(db, faculty.faculty_id)

    distance = calculate_distance(
        latitude, longitude,
        COLLEGE_LAT, COLLEGE_LON
    )

    if distance > ALLOWED_RADIUS_METERS:
        raise HTTPException(
            status_code=400,
            detail="You are outside the college campus"
        )

    existing = crud.get_today_attendance(db, faculty.faculty_id)
    if existing:
        if existing.status == "ABSENT":
            raise HTTPException(
                status_code=400,
                detail="You are already marked absent for today"
            )
        raise HTTPException(
            status_code=400,
            detail="Attendance already marked today"
        )

    image_bytes = await face_image.read()
    live_embedding = extract_face_embedding(image_bytes)

    if live_embedding is None:
        raise HTTPException(status_code=400, detail="Face not detected properly")

    stored_embedding = pickle.loads(faculty.face_embedding)

    if not compare_faces(live_embedding, stored_embedding):
        raise HTTPException(status_code=401, detail="Face not matched")

    status = "PRESENT"
    remarks = "Present"
    day_fraction = 1.0
    used_permission = False

    # =========================
    # LEAVE-BASED ATTENDANCE
    # =========================
    if today_leave:
        leave_part = (today_leave.permission_duration or "").strip().lower()

        # Full day leave
        if leave_part in ["full day", "full_day", ""]:
            raise HTTPException(
                status_code=400,
                detail="You are on full day leave today"
            )

        # Half day morning leave -> can come in afternoon
        elif leave_part in ["half day morning", "half_day_morning"]:
            if not (HALF_DAY_MORNING_CLOCK_IN_START <= current_time <= HALF_DAY_MORNING_CLOCK_IN_END):
                raise HTTPException(
                    status_code=400,
                    detail="For half day morning leave, clock-in is allowed only from 12:00 PM to 12:30 PM"
                )
            remarks = "Half Day - Morning Leave"
            day_fraction = 0.5

        # Half day afternoon leave -> normal morning attendance
        elif leave_part in ["half day afternoon", "half_day_afternoon"]:
            if not (CLOCK_IN_START <= current_time <= CLOCK_IN_END):
                raise HTTPException(
                    status_code=400,
                    detail="Clock-in allowed only from 9:00 AM to 9:30 AM"
                )
            remarks = "Half Day - Afternoon Leave"
            day_fraction = 0.5

    # =========================
    # NORMAL ATTENDANCE
    # =========================
    else:
        if current_time < CLOCK_IN_START:
            raise HTTPException(
                status_code=400,
                detail="Attendance opens at 9:00 AM"
            )

        if CLOCK_IN_START <= current_time <= CLOCK_IN_END:
            remarks = "Present"
            day_fraction = 1.0
            used_permission = False

        elif current_time > CLOCK_IN_END:
            monthly_permission_count = crud.get_monthly_permission_count(
                db,
                faculty.faculty_id
            )

            if monthly_permission_count < MAX_MONTHLY_PERMISSIONS:
                remarks = "Present - Late Entry"
                day_fraction = 1.0
                used_permission = True
            else:
                remarks = "Half Day - Morning Loss"
                day_fraction = 0.5
                used_permission = False

    attendance = crud.create_attendance(
        db=db,
        faculty_id=faculty.faculty_id,
        faculty_name=faculty.name,
        clock_in_time=current_time,
        status=status,
        remarks=remarks,
        day_fraction=day_fraction,
        used_permission=used_permission
    )

    return {
        "message": "Attendance marked successfully",
        "status": attendance.status,
        "remarks": attendance.remarks,
        "day_fraction": attendance.day_fraction,
        "used_permission": attendance.used_permission,
        "clock_in_time": str(attendance.clock_in_time)
    }

@router.post("/attendance/clock-out")
async def clock_out_attendance(
    latitude: float = Form(...),
    longitude: float = Form(...),
    face_image: UploadFile = File(...),
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    faculty = crud.get_faculty_by_email(db, current_user["email"])
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")

    validate_attendance_not_holiday(db, date.today())

    distance = calculate_distance(latitude, longitude, COLLEGE_LAT, COLLEGE_LON)
    if distance > ALLOWED_RADIUS_METERS:
        raise HTTPException(status_code=400, detail="You are outside the college campus")

    image_bytes = await face_image.read()
    live_embedding = extract_face_embedding(image_bytes)
    if live_embedding is None:
        raise HTTPException(status_code=400, detail="Face not detected properly")

    stored_embedding = pickle.loads(faculty.face_embedding)
    if not compare_faces(live_embedding, stored_embedding):
        raise HTTPException(status_code=401, detail="Face not matched")

    now = datetime.now()
    current_time = now.time()

    today_leave = get_today_approved_leave(db, faculty.faculty_id)

    if today_leave:
        leave_part = (today_leave.permission_duration or "").strip().lower()

        if leave_part in ["half day afternoon", "half_day_afternoon"]:
            if not (HALF_DAY_AFTERNOON_CLOCK_OUT_START <= current_time <= HALF_DAY_AFTERNOON_CLOCK_OUT_END):
                raise HTTPException(
                    status_code=400,
                    detail="For half day afternoon leave, clock-out is allowed only from 12:00 PM to 12:30 PM"
                )

    result = crud.clock_out_attendance(db, faculty.faculty_id, current_time)

    if result is None:
        raise HTTPException(status_code=400, detail="Clock-in not found for today")

    if result == "ABSENT_RECORD":
        raise HTTPException(status_code=400, detail="Cannot clock out because you are marked absent")

    if result == "CLOCK_IN_MISSING":
        raise HTTPException(status_code=400, detail="Clock-in missing for today")

    if result == "ALREADY_CLOCKED_OUT":
        raise HTTPException(status_code=400, detail="Already clocked out for today")

    if result == "INVALID_CLOCK_OUT":
        raise HTTPException(status_code=400, detail="Clock-out time must be after clock-in time")

    return {
        "message": "Clock-out marked successfully",
        "status": result.status,
        "remarks": result.remarks,
        "day_fraction": result.day_fraction,
        "clock_in_time": str(result.clock_in_time),
        "clock_out_time": str(result.clock_out_time),
        "working_hours": result.working_hours
    }

@router.get("/attendance/today-status")
def get_today_attendance_status(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    faculty = crud.get_faculty_by_email(db, current_user["email"])
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")

    today = date.today()
    now = datetime.now().time()

    # 1) Holiday / Sunday check
    try:
        validate_attendance_not_holiday(db, today)
    except HTTPException as e:
        return {
            "date": str(today),
            "status": "HOLIDAY",
            "remarks": e.detail,
            "message": e.detail,
            "clock_in_time": None,
            "clock_out_time": None,
            "working_hours": 0.0,
            "day_fraction": 0.0,
            "used_permission": False
        }

    # 2) First check actual attendance record
    attendance = crud.get_today_attendance(db, faculty.faculty_id)

    if attendance:
        return {
            "date": str(today),
            "status": attendance.status,
            "remarks": attendance.remarks,
            "message": "Attendance record found",
            "clock_in_time": str(attendance.clock_in_time) if attendance.clock_in_time else None,
            "clock_out_time": str(attendance.clock_out_time) if attendance.clock_out_time else None,
            "working_hours": attendance.working_hours,
            "auto_marked": attendance.auto_marked,
            "day_fraction": attendance.day_fraction,
            "used_permission": attendance.used_permission
        }

    # 3) If no attendance record, then check leave
    approved_leave = db.query(Leave).filter(
        Leave.faculty_id == faculty.faculty_id,
        Leave.status == "APPROVED",
        Leave.start_date <= today,
        Leave.end_date >= today
    ).first()

    if approved_leave:
        leave_part = (approved_leave.permission_duration or "").strip().lower()

        # Full day leave
        if leave_part in ["full day", "full_day", ""]:
            return {
                "date": str(today),
                "status": "ABSENT",
                "remarks": "On Leave",
                "message": "You are on leave today",
                "clock_in_time": None,
                "clock_out_time": None,
                "working_hours": 0.0,
                "day_fraction": 0.0,
                "used_permission": False
            }

        # Half day morning leave
        elif leave_part in ["half day morning", "half_day_morning"]:
            return {
                "date": str(today),
                "status": "ABSENT",
                "remarks": "Half Day Leave - Morning",
                "message": "You are on morning half-day leave today",
                "clock_in_time": None,
                "clock_out_time": None,
                "working_hours": 0.0,
                "day_fraction": 0.5,
                "used_permission": False
            }

        # Half day afternoon leave
        elif leave_part in ["half day afternoon", "half_day_afternoon"]:
            return {
                "date": str(today),
                "status": "ABSENT",
                "remarks": "Half Day Leave - Afternoon",
                "message": "You are on afternoon half-day leave today",
                "clock_in_time": None,
                "clock_out_time": None,
                "working_hours": 0.0,
                "day_fraction": 0.5,
                "used_permission": False
            }

    # 4) Normal flow if no leave and no attendance
    if now < CLOCK_IN_START:
        return {
            "date": str(today),
            "status": "NOT_OPEN",
            "remarks": None,
            "message": "Attendance opens at 9:00 AM",
            "clock_in_time": None,
            "clock_out_time": None,
            "working_hours": 0.0,
            "day_fraction": 0.0,
            "used_permission": False
        }

    if now <= AUTO_ABSENT_TIME:
        return {
            "date": str(today),
            "status": "NOT_MARKED",
            "remarks": None,
            "message": "Attendance not marked yet",
            "clock_in_time": None,
            "clock_out_time": None,
            "working_hours": 0.0,
            "day_fraction": 0.0,
            "used_permission": False
        }

    return {
        "date": str(today),
        "status": "ABSENT_PENDING_SYNC",
        "remarks": "Absent",
        "message": "Absent will be auto-marked or has not synced yet",
        "clock_in_time": None,
        "clock_out_time": None,
        "working_hours": 0.0,
        "day_fraction": 0.0,
        "used_permission": False
    }

@router.get("/attendance/history")
def get_attendance_history(
    start_date: date | None = None,
    end_date: date | None = None,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    faculty = crud.get_faculty_by_email(db, current_user["email"])
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")

    records = crud.get_attendance_history(
        db=db,
        faculty_id=faculty.faculty_id,
        start_date=start_date,
        end_date=end_date
    )

    return [
        {
            "id": row.id,
            "date": str(row.date),
            "faculty_id": row.faculty_id,
            "faculty_name": row.faculty_name,
            "clock_in_time": str(row.clock_in_time) if row.clock_in_time else None,
            "clock_out_time": str(row.clock_out_time) if row.clock_out_time else None,
            "status": row.status,
            "remarks": row.remarks,
            "day_fraction": row.day_fraction,
            "used_permission": row.used_permission,
            "working_hours": row.working_hours,
            "auto_marked": row.auto_marked
        }
        for row in records
    ]


@router.get("/attendance/report/summary")
def get_attendance_report_summary(
    start_date: date | None = None,
    end_date: date | None = None,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    faculty = crud.get_faculty_by_email(db, current_user["email"])
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")

    summary = crud.get_attendance_summary(
        db=db,
        faculty_id=faculty.faculty_id,
        start_date=start_date,
        end_date=end_date
    )

    return {
        "faculty_id": faculty.faculty_id,
        "faculty_name": faculty.name,
        "department": faculty.department,
        "start_date": str(start_date) if start_date else None,
        "end_date": str(end_date) if end_date else None,
        **summary
    }

# ---------- FORGET-PASSWORD ----------

@router.post("/forgot-password-link")
def forgot_password_link(
    data: schemas.ForgotPasswordRequest,
    db: Session = Depends(get_db)
):
    print("FORGOT PASSWORD API HIT")

    user = db.query(Faculty).filter(Faculty.email == data.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    token = generate_reset_token()
    user.reset_token = token
    user.reset_token_expiry = reset_token_expiry()

    db.commit()

    reset_link = f"https://nongrievously-unpickable-araceli.ngrok-free.dev/reset-password-redirect?token={token}"

    try:
        send_reset_email(user.email, reset_link)
    except Exception as e:
        print("EMAIL ERROR:", e)
        raise HTTPException(status_code=500, detail="Email failed to send")

    return {"message": "Password reset link sent"}


@router.post("/reset-password-link")
def reset_password_link(
    data: schemas.ResetPasswordWithTokenRequest,
    db: Session = Depends(get_db)
):
    # find user using reset token
    user = db.query(Faculty).filter(Faculty.reset_token == data.token).first()

    if not user:
        raise HTTPException(status_code=400, detail="Invalid reset token")

    if datetime.utcnow() > user.reset_token_expiry:
        raise HTTPException(status_code=400, detail="Reset link expired")

    # update password
    user.password = hash_password(data.new_password)

    # clear token after use
    user.reset_token = None
    user.reset_token_expiry = None

    db.commit()

    return {"message": "Password reset successful"}

@router.get("/reset-password-redirect")
def reset_password_redirect(token: str):
    deep_link = f"facultyapp://reset-password?token={token}"
    return RedirectResponse(url=deep_link)

# ================= UPDATE PROFILE =================
@router.put("/update-profile")
async def update_profile(
    name: str = Form(...),
    designation: str = Form(None),
    qualification: str = Form(None),
    profile_image: UploadFile = File(None),
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    faculty = db.query(Faculty).filter(Faculty.email == current_user["email"]).first()

    if not faculty:
        raise HTTPException(status_code=404, detail="User not found")

    faculty.name = name
    faculty.designation = designation
    faculty.qualification = qualification

    if profile_image:
        faculty.profile_image = await profile_image.read()

    db.commit()

    return {"message": "Profile updated successfully"}

@router.post("/upgrade-hod")
def upgrade_to_hod(
    faculty_id: str = Form(...),
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):

    if current_user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Only admin allowed")

    user = db.query(Faculty).filter(Faculty.faculty_id == faculty_id).first()

    if not user:
        raise HTTPException(status_code=404, detail="Faculty not found")

        # ❌ Prevent admin from becoming HOD
    if user.role == "admin":
        raise HTTPException(
            status_code=400,
            detail="Admin cannot be upgraded to HOD"
        )
        
    # 🔹 Check if department already has HOD
    existing_hod = db.query(Faculty).filter(
        Faculty.department == user.department,
        Faculty.role == "hod"
    ).first()

    if existing_hod:
        existing_hod.role = "faculty"
            
    user.role = "hod"

    db.commit()

    return {"message": f"{user.name} is now the HOD of {user.department}"}

@router.post("/upgrade-dean")
def upgrade_to_dean(
    faculty_id: str = Form(...),
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):

    if current_user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Only admin allowed")

    user = db.query(Faculty).filter(Faculty.faculty_id == faculty_id).first()

    if not user:
        raise HTTPException(status_code=404, detail="Faculty not found")

    # remove existing dean
    existing_dean = db.query(Faculty).filter(
        Faculty.role == "dean"
    ).first()

    if existing_dean:
        existing_dean.role = "faculty"

    user.role = "dean"

    db.commit()

    return {"message": f"{user.name} is now the Dean"}

@router.put("/assign-operator/{faculty_id}")
def assign_operator(
    faculty_id: str,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Only admin allowed")

    faculty = db.query(Faculty).filter(
        Faculty.faculty_id == faculty_id
    ).first()

    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")

    if faculty.role == "admin":
        raise HTTPException(status_code=400, detail="Admin cannot be assigned as operator")

    if faculty.role == "dean":
        raise HTTPException(status_code=400, detail="Dean cannot be assigned as operator")

    existing_operator = db.query(Faculty).filter(
        Faculty.department == faculty.department,
        Faculty.role == "operator"
    ).first()

    if existing_operator and existing_operator.faculty_id != faculty.faculty_id:
        raise HTTPException(
            status_code=400,
            detail=f"Operator already exists for {faculty.department}"
        )

    faculty.role = "operator"
    db.commit()
    db.refresh(faculty)

    return {
        "message": f"{faculty.name} is now operator of {faculty.department}",
        "faculty_id": faculty.faculty_id,
        "department": faculty.department,
        "role": faculty.role
    }
    
@router.get("/faculty-list")
def get_all_faculty(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db)
):

    if current_user["role"] not in ["admin", "operator", "hod", "dean"]:
        raise HTTPException(status_code=403, detail="Not Authorized")

    query = db.query(Faculty)
    
    # ✅ restrict for operator/hod (optional but recommended)
    if current_user["role"] in ["operator", "hod"]:
        query = query.filter(
            Faculty.department == current_user["department"]
        )

    users = query.all()

    return [
        {
            "faculty_id": u.faculty_id,
            "name": u.name,
            "email": u.email,
            "department": u.department,
            "role": u.role
        }
        for u in users
    ]

