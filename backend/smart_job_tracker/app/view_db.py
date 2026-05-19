
from app.database import SessionLocal
from app.models import Job

db = SessionLocal()
jobs = db.query(Job).all()

print(f"\n{'='*80}")
print(f"Total Jobs: {len(jobs)}")
print(f"{'='*80}\n")

for job in jobs:
    print(f"Title: {job.title}")
    print(f"Company: {job.company}")
    print(f"Location: {job.location}")
    print(f"Link: {job.link}")
    print(f"Applied: {job.applied}")
    print(f"Added: {job.created_at}")
    print(f"-" * 80)

db.close()