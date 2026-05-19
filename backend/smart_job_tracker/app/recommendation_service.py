"""
Recommendation service for job recommendations based on keyword matching.

Uses weighted keyword-based scoring to match user preferences and skills
with available job postings.
"""

import re
from typing import List, Set, Tuple
from sqlalchemy.orm import Session
from .models import User, Job, UserSkill


def normalize_keywords(text: str) -> Set[str]:
    """
    Normalize text to extract keywords.
    
    Steps:
    1. Convert to lowercase
    2. Remove special characters (keep letters, numbers, spaces)
    3. Split into tokens
    4. Remove empty strings
    
    Args:
        text: Text to normalize
        
    Returns:
        Set of normalized keywords
    """
    if not text:
        return set()
    
    # Lowercase
    text = text.lower()
    
    # Remove special characters, keep only alphanumeric and spaces
    text = re.sub(r'[^a-z0-9\s]', '', text)
    
    # Split into tokens and filter empty strings
    keywords = set(token for token in text.split() if token)
    
    return keywords


def extract_user_keywords(user: User, db: Session) -> Tuple[Set[str], Set[str], Set[str]]:
    """
    Extract keywords from user profile.
    
    Returns three sets:
    - skill_keywords: From user skills (highest weight)
    - preference_keywords: From job title preferences (medium weight)
    - location_keywords: From preferred location (medium weight)
    
    Args:
        user: User object from database
        db: Database session
        
    Returns:
        Tuple of (skill_keywords, preference_keywords, location_keywords)
    """
    skill_keywords = set()
    preference_keywords = set()
    location_keywords = set()
    
    # Extract skill keywords
    user_skills = db.query(UserSkill).filter(UserSkill.user_id == user.id).all()
    for skill in user_skills:
        skill_keywords.update(normalize_keywords(skill.skill_name))
    
    # Extract preference keywords from preferred job title
    if user.preferred_job_title:
        preference_keywords.update(normalize_keywords(user.preferred_job_title))
    
    # Extract location keywords from preferred location
    if user.preferred_location:
        location_keywords.update(normalize_keywords(user.preferred_location))
    
    return skill_keywords, preference_keywords, location_keywords


def extract_job_keywords(job: Job) -> Tuple[Set[str], Set[str], Set[str]]:
    """
    Extract keywords from job posting.
    
    Returns three sets:
    - title_keywords: From job title
    - description_keywords: From job description
    - location_keywords: From job location
    
    Args:
        job: Job object from database
        
    Returns:
        Tuple of (title_keywords, description_keywords, location_keywords)
    """
    title_keywords = normalize_keywords(job.title)
    description_keywords = normalize_keywords(job.description or "")
    location_keywords = normalize_keywords(job.location)
    
    return title_keywords, description_keywords, location_keywords


def calculate_relevance_score(
    user: User,
    job: Job,
    db: Session,
    skill_weight: float = 3.0,
    preference_weight: float = 1.5,
    location_weight: float = 1.5
) -> float:
    """
    Calculate relevance score for a job based on user profile.
    
    Scoring system:
    - Skill matches (from user skills vs job title + description): highest weight
    - Preference matches (from preferred job title vs job title): medium weight
    - Location matches (from preferred location vs job location): medium weight
    
    Args:
        user: User object
        job: Job object
        db: Database session
        skill_weight: Weight for skill matches (default: 3.0)
        preference_weight: Weight for preference matches (default: 1.5)
        location_weight: Weight for location matches (default: 1.5)
        
    Returns:
        Relevance score (0 or higher)
    """
    # Extract user keywords
    skill_keywords, user_pref_keywords, user_loc_keywords = extract_user_keywords(user, db)
    
    # Extract job keywords
    job_title_keywords, job_desc_keywords, job_loc_keywords = extract_job_keywords(job)
    
    # Combine job title and description keywords for skill matching
    job_skill_keywords = job_title_keywords | job_desc_keywords
    
    # Calculate matches
    skill_matches = len(skill_keywords & job_skill_keywords)
    preference_matches = len(user_pref_keywords & job_title_keywords)
    location_matches = len(user_loc_keywords & job_loc_keywords)
    
    # Calculate weighted score
    score = (skill_matches * skill_weight +
             preference_matches * preference_weight +
             location_matches * location_weight)
    
    return score


def get_job_recommendations(
    user: User,
    db: Session,
    limit: int = 10,
    skill_weight: float = 3.0,
    preference_weight: float = 1.5,
    location_weight: float = 1.5
) -> List[Tuple[Job, float]]:
    """
    Get personalized job recommendations for a user.
    
    Algorithm:
    1. Fetch all jobs from database
    2. Calculate relevance score for each job
    3. Filter jobs with score > 0 (at least one match)
    4. Sort by score in descending order
    5. Return top N results
    
    Args:
        user: User object
        db: Database session
        limit: Maximum number of recommendations to return (default: 10)
        skill_weight: Weight for skill matches
        preference_weight: Weight for preference matches
        location_weight: Weight for location matches
        
    Returns:
        List of (Job, score) tuples sorted by score descending
    """
    # Get all jobs
    all_jobs = db.query(Job).all()
    
    # Calculate scores for each job
    job_scores = []
    for job in all_jobs:
        score = calculate_relevance_score(
            user,
            job,
            db,
            skill_weight=skill_weight,
            preference_weight=preference_weight,
            location_weight=location_weight
        )
        # Include all jobs even with score 0 (no matches)
        job_scores.append((job, score))
    
    # Sort by score descending
    job_scores.sort(key=lambda x: x[1], reverse=True)
    
    # Return top N results
    return job_scores[:limit]
