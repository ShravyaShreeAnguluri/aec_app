from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models import Faculty
from app.auth import hash_password

def main():
    db: Session = SessionLocal()

    try:
        existing = db.query(Faculty).filter(
            Faculty.faculty_id == "OPCSE001"
        ).first()

        if existing:
            print("Operator already exists")
            return

        operator = Faculty(
            faculty_id="OPCSE001",
            name="CSE Operator",
            department="CSE",
            email="22a91a0505@aec.edu.in",
            password=hash_password("Operator@123"),
            designation="Operator",
            qualification="B.Tech",
            role="operator"
        )

        db.add(operator)
        db.commit()
        print("Operator created successfully")

    except Exception as e:
        db.rollback()
        print("Error:", e)
    finally:
        db.close()

if __name__ == "__main__":
    main()