from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.database import engine
from app import models
from app.routes import router
from app.scheduler import start_scheduler
from app.holiday.holiday_routes import router as holiday_router
from app.docs.docs_routes import router as docs_router
from app.timetable.timetable_routes import router as timetable_router
from app.admin.admin_routes import router as admin_router

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Faculty Face Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"],
)

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
app.mount("/certificates", StaticFiles(directory="certificates"), name="certificates")

app.include_router(router)
app.include_router(holiday_router)
app.include_router(docs_router)
app.include_router(timetable_router)
router.include_router(admin_router)

@app.on_event("startup")
def startup_event():
    start_scheduler()

@app.get("/")
def root():
    return {"message": "Faculty backend running"}