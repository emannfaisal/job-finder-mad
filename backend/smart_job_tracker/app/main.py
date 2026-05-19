from fastapi import FastAPI, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from . import schemas
from .database import init_db, get_db, SessionLocal
from .scraper_service import scrape_and_save_all, get_all_jobs
from .models import User
from .dependencies import get_auth_user
from .services.firebase_service import initialize_firebase
from .services.user_service import sync_user_from_firebase, save_job, unsave_job, get_user_saved_jobs, is_job_saved, update_user, add_user_skill, get_user_skills, delete_user_skill, delete_user_skill_by_name
from .recommendation_service import get_job_recommendations

app = FastAPI(title="Smart Job Tracker API")
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # for development only
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize database tables and Firebase on startup
@app.on_event("startup")
def startup():
    init_db()
    initialize_firebase()  # Initialize Firebase Admin SDK

@app.get("/")
def home():
    return {"message": "Job Tracker API is running"}

# ==================== AUTHENTICATION ENDPOINTS ====================

@app.post("/auth/sync-user", response_model=schemas.SyncUserResponse)
def sync_user(
    request: schemas.SyncUserRequest,
    db: Session = Depends(get_db)
):
    """
    Sync user from Firebase Authentication to database.
    
    Call this after user logs in via Firebase (Google, Email, etc).
    
    Flow:
    1. Client logs in with Firebase
    2. Firebase returns ID Token
    3. Client calls this endpoint with token
    4. Backend verifies token, creates/updates user in DB
    5. Return user profile
    
    Request body:
    {"token": "firebase_id_token_from_client"}
    """
    try:
        user = sync_user_from_firebase(db, request.token)
        return schemas.SyncUserResponse(
            user=schemas.UserResponse.from_orm(user),
            message="User synced successfully"
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Sync failed: {str(e)}")


@app.get("/users/me", response_model=schemas.UserResponse)
def get_current_user_profile(user: User = Depends(get_auth_user)):
    """Get current authenticated user profile. Protected route - requires Firebase ID token."""
    return user


@app.put("/users/me", response_model=schemas.UserResponse)
def update_current_user_profile(
    request: schemas.UpdateUserRequest,
    user: User = Depends(get_auth_user),
    db: Session = Depends(get_db)
):
    """
    Update current user profile (name, email, preferred_job_title, preferred_location).
    
    Protected route - requires Firebase ID token.
    
    Request body:
    {
        "name": "New Name",                      # optional
        "email": "new@email.com",               # optional
        "preferred_job_title": "Software Engineer",  # optional
        "preferred_location": "Remote"          # optional
    }
    
    At least one field must be provided. Email must be unique.
    """
    try:
        # Check if at least one field is provided
        if all(v is None for v in [request.name, request.email, request.preferred_job_title, request.preferred_location]):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="At least one field must be provided"
            )
        
        updated_user = update_user(
            db, 
            user.id, 
            name=request.name, 
            email=request.email,
            preferred_job_title=request.preferred_job_title,
            preferred_location=request.preferred_location
        )
        return updated_user
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@app.put("/users/me/preferred-job-title", response_model=schemas.UserResponse)
def update_preferred_job_title(
    request: schemas.UpdatePreferredJobTitleRequest,
    user: User = Depends(get_auth_user),
    db: Session = Depends(get_db)
):
    """
    Update preferred job title for the current user.
    
    Protected route - requires Firebase ID token.
    
    Request body:
    {"preferred_job_title": "Software Engineer"}
    """
    try:
        updated_user = update_user(db, user.id, preferred_job_title=request.preferred_job_title)
        return updated_user
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@app.put("/users/me/preferred-location", response_model=schemas.UserResponse)
def update_preferred_location(
    request: schemas.UpdatePreferredLocationRequest,
    user: User = Depends(get_auth_user),
    db: Session = Depends(get_db)
):
    """
    Update preferred location for the current user.
    
    Protected route - requires Firebase ID token.
    
    Request body:
    {"preferred_location": "Remote"}
    """
    try:
        updated_user = update_user(db, user.id, preferred_location=request.preferred_location)
        return updated_user
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


# ==================== SAVED JOBS ENDPOINTS ====================

@app.post("/jobs/save")
def save_job_endpoint(
    request: schemas.SaveJobRequest,
    user: User = Depends(get_auth_user),
    db: Session = Depends(get_db)
):
    """
    Save a job for the current user.
    
    Protected route - requires Firebase ID token.
    
    Request:
    {"job_id": 123}
    
    Response:
    {"saved": true, "message": "Job saved successfully", "saved_job_id": 1}
    """
    try:
        saved_job = save_job(db, user.id, request.job_id)
        return {"saved": True, "message": "Job saved successfully", "saved_job_id": saved_job.id}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@app.post("/jobs/unsave")
def unsave_job_endpoint(
    request: schemas.SaveJobRequest,
    user: User = Depends(get_auth_user),
    db: Session = Depends(get_db)
):
    """
    Unsave a job for the current user.
    
    Protected route - requires Firebase ID token.
    
    Request:
    {"job_id": 123}
    """
    deleted = unsave_job(db, user.id, request.job_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Saved job not found")
    return {"unsaved": True, "message": "Job unsaved successfully"}


@app.get("/users/me/saved-jobs", response_model=List[schemas.SavedJobResponse])
def get_my_saved_jobs(
    user: User = Depends(get_auth_user),
    db: Session = Depends(get_db),
    limit: int = 50,
    offset: int = 0
):
    """
    Get all saved jobs for the current user with pagination.
    
    Protected route - requires Firebase ID token.
    
    Query parameters:
    - limit: Results per page (default: 50, max: 100)
    - offset: Pagination offset (default: 0)
    """
    saved_jobs = get_user_saved_jobs(db, user.id, limit=min(limit, 100), offset=offset)
    return saved_jobs


@app.get("/jobs/{job_id}/is-saved")
def check_job_saved(
    job_id: int,
    user: User = Depends(get_auth_user),
    db: Session = Depends(get_db)
):
    """
    Check if a job is saved by the current user.
    
    Protected route - requires Firebase ID token.
    
    Response:
    {"saved": true}
    """
    is_saved = is_job_saved(db, user.id, job_id)
    return {"saved": is_saved}


# ==================== USER SKILLS ENDPOINTS ====================

@app.post("/users/me/skills")
def add_user_skill_endpoint(
    request: schemas.AddUserSkillRequest,
    user: User = Depends(get_auth_user),
    db: Session = Depends(get_db)
):
    """
    Add a skill to the current user's profile.
    
    Protected route - requires Firebase ID token.
    
    Request:
    {"skill_name": "Python"}
    
    Response:
    {"added": true, "message": "Skill added successfully", "skill_id": 1}
    """
    try:
        user_skill = add_user_skill(db, user.id, request.skill_name)
        return {"added": True, "message": "Skill added successfully", "skill_id": user_skill.id}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@app.get("/users/me/skills", response_model=List[schemas.UserSkillResponse])
def get_user_skills_endpoint(
    user: User = Depends(get_auth_user),
    db: Session = Depends(get_db)
):
    """
    Get all skills for the current user.
    
    Protected route - requires Firebase ID token.
    """
    skills = get_user_skills(db, user.id)
    return skills


@app.delete("/users/me/skills/{skill_id}")
def delete_user_skill_endpoint(
    skill_id: int,
    user: User = Depends(get_auth_user),
    db: Session = Depends(get_db)
):
    """
    Delete a skill from the current user's profile.
    
    Protected route - requires Firebase ID token.
    
    Response:
    {"deleted": true, "message": "Skill deleted successfully"}
    """
    deleted = delete_user_skill(db, user.id, skill_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Skill not found")
    return {"deleted": True, "message": "Skill deleted successfully"}


@app.delete("/users/me/skills/by-name/{skill_name}")
def delete_user_skill_by_name_endpoint(
    skill_name: str,
    user: User = Depends(get_auth_user),
    db: Session = Depends(get_db)
):
    """
    Delete a skill from the current user's profile by skill name.
    
    Protected route - requires Firebase ID token.
    
    Response:
    {"deleted": true, "message": "Skill deleted successfully"}
    """
    deleted = delete_user_skill_by_name(db, user.id, skill_name)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Skill not found")
    return {"deleted": True, "message": "Skill deleted successfully"}


# ==================== CELERY TASK ENDPOINTS ====================

from .celery_worker import celery_app, scrape_jobs_task
from celery.result import AsyncResult

@app.post("/scrape/", status_code=202)
def trigger_scrape():
    """Trigger the Celery worker manually via API."""
    task = scrape_jobs_task.delay()
    print(f"📤 Task queued: {task.id}")
    return {"status": "Scraping queued", "task_id": task.id}

@app.get("/task-status/{task_id}")
def get_task_status(task_id: str):
    """Check status of a Celery task."""
    task_result = AsyncResult(task_id, app=celery_app)
    print(f"📊 Checking task {task_id}: state={task_result.state}")
    
    return {
        "task_id": task_id,
        "status": task_result.state,
        "result": task_result.result if task_result.state == "SUCCESS" else None,
        "error": str(task_result.info) if task_result.state == "FAILURE" else None
    }

@app.get("/jobs/", response_model=List[schemas.JobResponse])
def get_jobs_list(db: Session = Depends(get_db)):
    """Get all jobs from database."""
    jobs = get_all_jobs(db)
    return jobs

@app.get("/jobs/search")
def search_jobs_endpoint(
    query: str = None,
    location: str = None,
    company: str = None,
    limit: int = 20,
    offset: int = 0,
    sort_by: str = "created_at",
    sort_order: str = "desc",
    db: Session = Depends(get_db)
):
    """
    Advanced job search with filtering and pagination.
    
    Query parameters:
    - query: Search in title/description
    - location: Filter by location
    - company: Filter by company (DubizzleLabs, 10Pearls, SAPSystems)
    - limit: Results per page (max 100, default 20)
    - offset: Pagination offset (default 0)
    - sort_by: created_at, title, company (default: created_at)
    - sort_order: asc, desc (default: desc)
    
    Example:
    /jobs/search?query=python&location=karachi&limit=10&sort_by=title
    """
    from .scraper_service import search_jobs
    
    print(f"🔍 Search: query={query}, location={location}, company={company}, limit={limit}")
    
    result = search_jobs(
        db, 
        query=query,
        location=location,
        company=company,
        limit=limit,
        offset=offset,
        sort_by=sort_by,
        sort_order=sort_order
    )
    
    return result

@app.get("/jobs/stats")
def get_jobs_stats(db: Session = Depends(get_db)):
    """Get statistics about jobs in database."""
    from .scraper_service import get_job_stats
    
    stats = get_job_stats(db)
    print(f"📊 Stats: {stats}")
    
    return stats

@app.get("/jobs/location/{location}")
def get_jobs_location(location: str, db: Session = Depends(get_db)):
    """Get jobs filtered by location."""
    from .scraper_service import get_jobs_by_location
    jobs = get_jobs_by_location(db, location)
    return jobs

@app.get("/jobs/company/{company}")
def get_jobs_company(company: str, db: Session = Depends(get_db)):
    """Get jobs filtered by company/source (DubizzleLabs, 10Pearls, SAPSystems)."""
    from .scraper_service import get_jobs_by_company
    jobs = get_jobs_by_company(db, company)
    return jobs


# ==================== RECOMMENDATIONS ENDPOINT ====================

@app.get("/recommendations", response_model=List[schemas.RecommendationResponse])
def get_recommendations(
    user: User = Depends(get_auth_user),
    db: Session = Depends(get_db),
    limit: int = 10
):
    """
    Get personalized job recommendations for the current user.
    
    Uses a keyword-based content matching system that analyzes:
    - User skills (highest weight)
    - User preferred job title (medium weight)
    - User preferred location (medium weight)
    
    Against job postings:
    - Job title and description
    - Job location
    
    Protected route - requires Firebase ID token.
    
    Query parameters:
    - limit: Maximum number of recommendations (default: 10, max: 50)
    
    Response:
    [
      {
        "id": 1,
        "title": "Senior Python Developer",
        "company": "DubizzleLabs",
        "location": "Remote",
        "description": "...",
        "link": "https://...",
        "applied": false,
        "score": 15.0
      },
      ...
    ]
    
    Scoring explanation:
    - score: Relevance score based on keyword matches (higher = more relevant)
    - If score is 0, no keywords matched the job posting
    """
    try:
        # Cap limit to prevent abuse
        limit = min(limit, 50)
        
        # Get recommendations with scores
        recommendations = get_job_recommendations(user, db, limit=limit)
        
        # Convert to response schema with scores
        result = []
        for job, score in recommendations:
            rec = schemas.RecommendationResponse(
                id=job.id,
                title=job.title,
                company=job.company,
                location=job.location,
                description=job.description,
                link=job.link,
                applied=job.applied,
                score=score
            )
            result.append(rec)
        
        return result
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate recommendations: {str(e)}"
        )