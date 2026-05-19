"""
User service - handles user sync, CRUD operations, and Firebase authentication.
"""

from sqlalchemy.orm import Session
from sqlalchemy import select
from ..models import User, SavedJob, Job, UserSkill
from ..services.firebase_service import verify_firebase_token
from .. import schemas
import logging

logger = logging.getLogger(__name__)


def sync_user_from_firebase(db: Session, token: str) -> User:
    """
    Verify Firebase token and sync/create user in database.
    
    Flow:
    1. Verify token with Firebase
    2. Extract uid, email, name
    3. Check if user exists in DB
    4. Create or update user
    5. Return user object
    
    Args:
        db: Database session
        token: Firebase ID token from client
        
    Returns:
        User object from database
        
    Raises:
        ValueError: If token invalid
    """
    logger.info("[AUTH] 🔄 Syncing user from Firebase token...")
    
    # Step 1: Verify token with Firebase
    decoded_token = verify_firebase_token(token)
    
    # Step 2: Extract user info
    firebase_uid = decoded_token.get("uid")
    email = decoded_token.get("email")
    name = decoded_token.get("name") or email.split("@")[0]
    
    # Step 3: Check if user exists
    stmt = select(User).where(User.firebase_uid == firebase_uid)
    existing_user = db.execute(stmt).scalar_one_or_none()
    
    if existing_user:
        # Update existing user
        existing_user.email = email
        existing_user.name = name
        db.commit()
        db.refresh(existing_user)
        logger.info(f"[AUTH] ℹ️ User updated: {email}")
        return existing_user
    
    # Step 4: Create new user
    new_user = User(
        firebase_uid=firebase_uid,
        email=email,
        name=name
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    logger.info(f"[AUTH] ✅ New user created: {email}")
    
    return new_user


def get_current_user_from_token(db: Session, token: str) -> User:
    """
    Get current authenticated user from Firebase token.
    
    Verifies token, extracts uid, and fetches user from DB.
    
    Args:
        db: Database session
        token: Firebase ID token
        
    Returns:
        User object from database
        
    Raises:
        ValueError: If token invalid or user not found in DB
    """
    logger.info("[AUTH] 👤 Getting current user...")
    
    # Verify token
    decoded_token = verify_firebase_token(token)
    firebase_uid = decoded_token.get("uid")
    
    # Fetch user from DB
    stmt = select(User).where(User.firebase_uid == firebase_uid)
    user = db.execute(stmt).scalar_one_or_none()
    
    if not user:
        logger.error(f"[AUTH] ❌ User not found in DB: {firebase_uid}")
        raise ValueError(
            f"User {firebase_uid} not found in database. Please sync user first via /auth/sync-user"
        )
    
    logger.info(f"[AUTH] ✅ User authenticated: {user.email}")
    return user


def get_user_by_email(db: Session, email: str) -> User | None:
    """Get user by email."""
    stmt = select(User).where(User.email == email)
    return db.execute(stmt).scalar_one_or_none()


def get_user_by_id(db: Session, user_id: int) -> User | None:
    """Get user by ID."""
    stmt = select(User).where(User.id == user_id)
    return db.execute(stmt).scalar_one_or_none()


def get_user_by_firebase_uid(db: Session, firebase_uid: str) -> User | None:
    """Get user by Firebase UID."""
    stmt = select(User).where(User.firebase_uid == firebase_uid)
    return db.execute(stmt).scalar_one_or_none()


def create_user(db: Session, email: str, name: str, firebase_uid: str) -> User:
    """Create a new user in the database."""
    new_user = User(
        email=email,
        name=name,
        firebase_uid=firebase_uid
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    logger.info(f"[USER] ✅ User created: {email}")
    return new_user


def update_user(db: Session, user_id: int, name: str = None, email: str = None, preferred_job_title: str = None, preferred_location: str = None) -> User:
    """
    Update user profile (name, email, preferred_job_title, preferred_location).
    
    Args:
        db: Database session
        user_id: User ID to update
        name: New name (optional)
        email: New email (optional)
        preferred_job_title: Preferred job title (optional)
        preferred_location: Preferred job location (optional)
        
    Returns:
        Updated User object
        
    Raises:
        ValueError: If user not found or email already exists
    """
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user:
        raise ValueError(f"User {user_id} not found")
    
    # Check if email is already taken by another user
    if email and email != user.email:
        existing_email = db.query(User).filter(
            (User.email == email) & (User.id != user_id)
        ).first()
        if existing_email:
            raise ValueError(f"Email {email} already exists")
    
    # Update fields
    if name is not None:
        user.name = name
    if email is not None:
        user.email = email
    if preferred_job_title is not None:
        user.preferred_job_title = preferred_job_title
    if preferred_location is not None:
        user.preferred_location = preferred_location
    
    db.commit()
    db.refresh(user)
    logger.info(f"[USER] ✅ User {user_id} updated: name={name}, email={email}, preferred_job_title={preferred_job_title}, preferred_location={preferred_location}")
    
    return user


# ==================== SAVED JOBS FUNCTIONS ====================

def save_job(db: Session, user_id: int, job_id: int) -> SavedJob:
    """
    Save a job for a user.
    
    Args:
        db: Database session
        user_id: User ID
        job_id: Job ID
        
    Returns:
        SavedJob object
        
    Raises:
        ValueError: If job already saved or doesn't exist
    """
    # Check if job already saved
    stmt = select(SavedJob).where(
        (SavedJob.user_id == user_id) & (SavedJob.job_id == job_id)
    )
    existing = db.execute(stmt).scalar_one_or_none()
    
    if existing:
        raise ValueError(f"Job {job_id} already saved")
    
    # Check if job exists
    job = db.query(Job).filter(Job.id == job_id).first()
    if not job:
        raise ValueError(f"Job {job_id} not found")
    
    # Create saved job record
    saved_job = SavedJob(user_id=user_id, job_id=job_id)
    db.add(saved_job)
    db.commit()
    db.refresh(saved_job)
    logger.info(f"[JOBS] ✅ Job {job_id} saved by user {user_id}")
    
    return saved_job


def unsave_job(db: Session, user_id: int, job_id: int) -> bool:
    """
    Unsave a job for a user.
    
    Args:
        db: Database session
        user_id: User ID
        job_id: Job ID
        
    Returns:
        True if deleted, False if not found
    """
    stmt = select(SavedJob).where(
        (SavedJob.user_id == user_id) & (SavedJob.job_id == job_id)
    )
    saved_job = db.execute(stmt).scalar_one_or_none()
    
    if not saved_job:
        return False
    
    db.delete(saved_job)
    db.commit()
    logger.info(f"[JOBS] ✅ Job {job_id} unsaved by user {user_id}")
    
    return True


def get_user_saved_jobs(db: Session, user_id: int, limit: int = 50, offset: int = 0) -> list:
    """
    Get all saved jobs for a user with pagination.
    
    Args:
        db: Database session
        user_id: User ID
        limit: Results per page
        offset: Pagination offset
        
    Returns:
        List of SavedJob objects
    """
    stmt = select(SavedJob).where(SavedJob.user_id == user_id).order_by(SavedJob.created_at.desc()).limit(limit).offset(offset)
    return db.execute(stmt).scalars().all()


def is_job_saved(db: Session, user_id: int, job_id: int) -> bool:
    """Check if a job is saved by a user."""
    stmt = select(SavedJob).where(
        (SavedJob.user_id == user_id) & (SavedJob.job_id == job_id)
    )
    return db.execute(stmt).scalar_one_or_none() is not None


# ==================== USER SKILLS FUNCTIONS ====================

def add_user_skill(db: Session, user_id: int, skill_name: str) -> UserSkill:
    """
    Add a skill to a user.
    
    Args:
        db: Database session
        user_id: User ID
        skill_name: Skill name to add
        
    Returns:
        UserSkill object
        
    Raises:
        ValueError: If user not found or skill already exists
    """
    # Check if user exists
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise ValueError(f"User {user_id} not found")
    
    # Check if skill already exists for this user
    stmt = select(UserSkill).where(
        (UserSkill.user_id == user_id) & (UserSkill.skill_name == skill_name.lower())
    )
    existing = db.execute(stmt).scalar_one_or_none()
    
    if existing:
        raise ValueError(f"Skill '{skill_name}' already exists for this user")
    
    # Create skill record
    user_skill = UserSkill(user_id=user_id, skill_name=skill_name.lower())
    db.add(user_skill)
    db.commit()
    db.refresh(user_skill)
    logger.info(f"[SKILLS] ✅ Skill '{skill_name}' added to user {user_id}")
    
    return user_skill


def get_user_skills(db: Session, user_id: int) -> list:
    """
    Get all skills for a user.
    
    Args:
        db: Database session
        user_id: User ID
        
    Returns:
        List of UserSkill objects
    """
    stmt = select(UserSkill).where(UserSkill.user_id == user_id).order_by(UserSkill.created_at.desc())
    return db.execute(stmt).scalars().all()


def delete_user_skill(db: Session, user_id: int, skill_id: int) -> bool:
    """
    Delete a skill from a user.
    
    Args:
        db: Database session
        user_id: User ID
        skill_id: Skill ID to delete
        
    Returns:
        True if deleted, False if not found
    """
    stmt = select(UserSkill).where(
        (UserSkill.user_id == user_id) & (UserSkill.id == skill_id)
    )
    user_skill = db.execute(stmt).scalar_one_or_none()
    
    if not user_skill:
        return False
    
    db.delete(user_skill)
    db.commit()
    logger.info(f"[SKILLS] ✅ Skill {skill_id} deleted for user {user_id}")
    
    return True


def delete_user_skill_by_name(db: Session, user_id: int, skill_name: str) -> bool:
    """
    Delete a skill from a user by skill name.
    
    Args:
        db: Database session
        user_id: User ID
        skill_name: Skill name to delete
        
    Returns:
        True if deleted, False if not found
    """
    stmt = select(UserSkill).where(
        (UserSkill.user_id == user_id) & (UserSkill.skill_name == skill_name.lower())
    )
    user_skill = db.execute(stmt).scalar_one_or_none()
    
    if not user_skill:
        return False
    
    db.delete(user_skill)
    db.commit()
    logger.info(f"[SKILLS] ✅ Skill '{skill_name}' deleted for user {user_id}")
    
    return True
