"""
Quick script to scrape all job sources and save to database.
Run this from the root directory: python -m run_scraper
"""

from app.database import SessionLocal, init_db
from app.scraper_service import scrape_and_save_all

if __name__ == "__main__":
    print("Initializing database...")
    init_db()
    
    print("\nStarting scraper...")
    db = SessionLocal()
    result = scrape_and_save_all(db)
    print(f"\nDone! Saved {result['saved']} jobs, Skipped {result['skipped']} duplicates")
