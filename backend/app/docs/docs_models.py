from sqlalchemy import Column, Integer, String, Text, BigInteger
from app.database import Base


class Subject(Base):
    __tablename__ = "subjects"

    id = Column(Integer, primary_key=True, index=True)
    department = Column(String, nullable=False)
    name = Column(String, nullable=False)
    code = Column(String, nullable=False, unique=True, index=True)
    year = Column(Integer, nullable=False)
    semester = Column(Integer, nullable=False)
    description = Column(Text, nullable=True, default="")
    created_at = Column(String, nullable=True)


class Document(Base):
    __tablename__ = "documents"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True, default="")
    file_name = Column(String, nullable=False)
    original_name = Column(String, nullable=False)
    file_type = Column(String, nullable=False)
    file_size = Column(BigInteger, nullable=False)
    file_path = Column(String, nullable=False)
    year = Column(Integer, nullable=False)
    department = Column(String, nullable=False)
    subject = Column(String, nullable=False)
    subject_name = Column(String, nullable=False)
    category = Column(String, nullable=False, default="Lecture Notes")
    uploaded_by = Column(String, nullable=False, default="Faculty")
    download_count = Column(Integer, nullable=False, default=0)
    created_at = Column(String, nullable=True)


class Certificate(Base):
    __tablename__ = "certificates"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    faculty_name = Column(String, nullable=False)
    department = Column(String, nullable=False)
    type = Column(String, nullable=False)
    issued_by = Column(String, nullable=False)
    issue_date = Column(String, nullable=False)
    file_name = Column(String, nullable=False)
    original_name = Column(String, nullable=False)
    file_type = Column(String, nullable=False)
    file_size = Column(BigInteger, nullable=False)
    file_path = Column(String, nullable=False)
    created_at = Column(String, nullable=True)