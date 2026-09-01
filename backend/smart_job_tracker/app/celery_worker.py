import os
from celery import Celery
from celery.schedules import crontab
from .config import load_environment
from .database import SessionLocal
from .scraper_service import scrape_and_save_all

load_environment()

broker_url = os.getenv("CELERY_BROKER_URL", "redis://localhost:6379/0")
result_backend = os.getenv("CELERY_RESULT_BACKEND", broker_url)

celery_app = Celery(
    "worker",
    broker=broker_url,
    backend=result_backend,
)

print(f"[CELERY] Initialized with Redis broker/backend at {broker_url}")

# Celery Configuration
celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
)

@celery_app.task(name="scrape_jobs_task")
def scrape_jobs_task():
    """Celery task to trigger the scraper service."""
    print("[TASK] 🚀 scrape_jobs_task started")
    db = SessionLocal()
    try:
        result = scrape_and_save_all(db)
        print(f"[TASK] ✅ scrape_jobs_task completed: {result}")
        return result
    except Exception as e:
        print(f"[TASK] ❌ Error: {e}")
        raise
    finally:
        db.close()

# Schedule the task every 24 hours
celery_app.conf.beat_schedule = {
    "run-scraper-every-24-hours": {
        "task": "scrape_jobs_task",
        "schedule": crontab(hour=0, minute=0), # Runs at midnight every day
    },
}