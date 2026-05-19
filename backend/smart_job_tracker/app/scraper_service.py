from sqlalchemy.orm import Session
from .models import Job
from .dubizzle_scraper import DubizzleScraper
from .pearlsscraper_logic import TenPearlsScraper
from .systems_scraper import SAPSystemsScraper


def scrape_and_save_all(db: Session):
    """Scrape all job sources and save to database, avoiding duplicates."""
    scrapers = [
        DubizzleScraper("DubizzleLabs"),
        TenPearlsScraper("10Pearls"),
        SAPSystemsScraper("SAPSystems"),
    ]
    total_saved = 0
    total_skipped = 0
    
    for scraper in scrapers:
        try:
            print(f"\n🔄 Starting {scraper.name}...")
            jobs = scraper.scrape()
            print(f"📊 Scraped {len(jobs)} jobs from {scraper.name}")
            
            for job in jobs:
                try:
                    # Check if job already exists by link (UNIQUE constraint)
                    existing = db.query(Job).filter(Job.link == job["link"]).first()
                    
                    if existing:
                        print(f"⏭️  Skipped (duplicate): {job['title']}")
                        total_skipped += 1
                        continue
                    
                    # Create new job record
                    new_job = Job(
                        title=job.get("title", ""),
                        company=scraper.name,  # Store scraper name as company
                        location=job.get("location", ""),
                        link=job.get("link", ""),
                        description=f"Remote: {job.get('remote', False)}" if job.get("remote") else None,
                    )
                    
                    db.add(new_job)
                    db.commit()  # Commit each job individually
                    print(f"✅ Saved: {job['title']}")
                    total_saved += 1
                    
                except Exception as e:
                    db.rollback()  # Rollback only this job, not the entire batch
                    print(f"❌ Error saving job: {e}")
                    total_skipped += 1
                    continue
            
        except Exception as e:
            print(f"❌ Error with {scraper.name}: {e}")
            db.rollback()
            continue
    print(f"\n{'='*60}")
    print(f"✅ Saved: {total_saved} jobs")
    print(f"⏭️  Skipped: {total_skipped} jobs (duplicates or errors)")
    print(f"{'='*60}")
    return {
        "saved": total_saved,
        "skipped": total_skipped,
    }


def get_all_jobs(db: Session):
    """Get all jobs from database."""
    return db.query(Job).all()

def get_jobs_by_location(db: Session, location: str):
    """Get jobs filtered by location."""
    return db.query(Job).filter(
        Job.location.ilike(f"%{location}%")
    ).all()

def get_jobs_by_company(db: Session, company: str):
    """Get jobs filtered by company/source."""
    return db.query(Job).filter(Job.company == company).all()


# ========== OPTIMIZED SEARCH FUNCTIONS ==========

def search_jobs(
    db: Session,
    query: str = None,
    location: str = None,
    company: str = None,
    limit: int = 20,
    offset: int = 0,
    sort_by: str = "created_at",
    sort_order: str = "desc"
):
    """
    Advanced job search with pagination, filtering, and sorting.
    
    Args:
        query: Search in title and description
        location: Filter by location (partial match)
        company: Filter by company (exact match)
        limit: Number of results per page (max 100)
        offset: Pagination offset
        sort_by: Field to sort by (created_at, title, company)
        sort_order: asc or desc
    
    Returns:
        dict with jobs list and pagination info
    """
    # Validate inputs
    limit = min(limit, 100)  # Max 100 per page
    offset = max(offset, 0)
    sort_order = "asc" if sort_order.lower() == "asc" else "desc"
    
    # Build base query
    q = db.query(Job)
    
    # Apply filters
    if query:
        q = q.filter(
            Job.title.ilike(f"%{query}%") | 
            Job.description.ilike(f"%{query}%")
        )
    
    if location:
        q = q.filter(Job.location.ilike(f"%{location}%"))
    
    if company:
        q = q.filter(Job.company == company)
    
    # Get total count before pagination
    total = q.count()
    
    # Apply sorting
    if sort_by == "title":
        q = q.order_by(Job.title.asc() if sort_order == "asc" else Job.title.desc())
    elif sort_by == "company":
        q = q.order_by(Job.company.asc() if sort_order == "asc" else Job.company.desc())
    else:  # Default: created_at
        q = q.order_by(Job.created_at.asc() if sort_order == "asc" else Job.created_at.desc())
    
    # Apply pagination
    jobs = q.limit(limit).offset(offset).all()
    
    return {
        "jobs": jobs,
        "total": total,
        "limit": limit,
        "offset": offset,
        "pages": (total + limit - 1) // limit  # Ceiling division
    }


def get_job_stats(db: Session):
    """Get statistics about jobs in database."""
    from sqlalchemy import func
    
    total_jobs = db.query(Job).count()
    companies = db.query(Job.company, func.count(Job.id)).group_by(Job.company).all()
    
    return {
        "total_jobs": total_jobs,
        "companies": {company: count for company, count in companies}
    }
