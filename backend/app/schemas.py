from pydantic import BaseModel, EmailStr, Field, field_validator
import re


# =====================================================
# BASE SCHEMA (REUSABLE EMAIL VALIDATION)
# =====================================================
class EmailBase(BaseModel):
    email: EmailStr

    @field_validator("email")
    @classmethod
    def validate_email_domain(cls, v: str):
        allowed_domains = [
            "gmail.com",
            "outlook.com",
            "hotmail.com",
            "yahoo.com",
            "icloud.com",
            "aec.edu.in",
        ]

        domain = v.split("@")[-1].strip().lower()
        if domain not in allowed_domains:
            raise ValueError("Only gmail.com or aec.edu.in and other allowed email domains are accepted")

        return v

# ---------- REGISTER SCHEMA ----------
class FacultyCreate(EmailBase):
    faculty_id: str = Field(..., min_length=3)
    name: str = Field(..., min_length=2)
    department: str = Field(..., min_length=2)
    password: str = Field(..., min_length=6)
    role: str
    designation: str | None = None
    qualification: str | None = None

    @field_validator("role")
    @classmethod
    def validate_role(cls, v):
        if v != "faculty":
            raise ValueError("Invalid role")
        return v

    @field_validator("password")
    @classmethod
    def strong_password(cls, v: str):
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain at least one number")
        if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", v):
            raise ValueError("Password must contain at least one special character")
        if " " in v:
            raise ValueError("Password must not contain spaces")
        return v


# ---------- RESPONSE SCHEMA ----------
class FacultyResponse(BaseModel):
    id: int
    faculty_id: str
    name: str
    department: str
    email: str
    role: str
    profile_image: str | None = None
    designation: str | None = None
    qualification: str | None = None

    class Config:
        from_attributes = True


# ---------- LOGIN SCHEMA ----------
class LoginRequest(EmailBase):
    password: str = Field(..., min_length=6, max_length=72)


class OTPVerifyRequest(EmailBase):
    otp: str = Field(..., min_length=6, max_length=6)

class OTPRequest(BaseModel):
    email: EmailStr

class OTPVerify(BaseModel):
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6)

class ForgotPasswordRequest(EmailBase):
    pass


class ResetPasswordWithTokenRequest(BaseModel):
    token: str
    new_password: str = Field(..., min_length=6)

    @field_validator("new_password")
    @classmethod
    def strong_password(cls, v: str):
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain at least one number")
        if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", v):
            raise ValueError("Password must contain at least one special character")
        if " " in v:
            raise ValueError("Password must not contain spaces")
        return v

class DepartmentResponse(BaseModel):
    id: int
    name: str

    class Config:
        from_attributes = True