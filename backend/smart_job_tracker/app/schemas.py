from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime

# ==================== JOB SCHEMAS ====================

class JobBase(BaseModel):
    title: str
    company: str
    location: str
    link: str
    description: Optional[str] = None

class JobCreate(JobBase):
    pass

class JobResponse(JobBase):
    id: int
    applied: bool
    created_at: datetime

    class Config:
        from_attributes = True


# ==================== SAVED JOB SCHEMAS ====================

class SavedJobResponse(BaseModel):
    """Saved job response schema."""
    id: int
    job_id: int
    user_id: int
    created_at: datetime
    job: JobResponse  # Nested job details
    
    class Config:
        from_attributes = True


class SaveJobRequest(BaseModel):
    """Request to save a job."""
    job_id: int


# ==================== USER SKILL SCHEMAS ====================

class UserSkillResponse(BaseModel):
    """User skill response schema."""
    id: int
    user_id: int
    skill_name: str
    created_at: datetime
    
    class Config:
        from_attributes = True


class AddUserSkillRequest(BaseModel):
    """Request to add a skill to user."""
    skill_name: str


# ==================== USER SCHEMAS ====================

class UserBase(BaseModel):
    email: EmailStr
    name: Optional[str] = None


class UserCreate(UserBase):
    firebase_uid: str


class UserResponse(UserBase):
    """User response schema - returned by API."""
    id: int
    firebase_uid: str
    preferred_job_title: Optional[str] = None
    preferred_location: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class UserWithSavedJobs(UserResponse):
    """User response with saved jobs."""
    saved_jobs: List[SavedJobResponse] = []
    
    class Config:
        from_attributes = True


class UserWithSkills(UserResponse):
    """User response with skills."""
    skills: List[UserSkillResponse] = []
    
    class Config:
        from_attributes = True


class UpdateUserRequest(BaseModel):
    """Request to update user profile."""
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    preferred_job_title: Optional[str] = None
    preferred_location: Optional[str] = None


class UpdatePreferredJobTitleRequest(BaseModel):
    """Request to update preferred job title."""
    preferred_job_title: str


class UpdatePreferredLocationRequest(BaseModel):
    """Request to update preferred location."""
    preferred_location: str


class SyncUserRequest(BaseModel):
    """Firebase token sync request from client."""
    token: str


class SyncUserResponse(BaseModel):
    """Response after user sync."""
    user: UserResponse
    message: str


# ==================== RECOMMENDATION SCHEMAS ====================

class RecommendationResponse(BaseModel):
    """Recommended job with relevance score."""
    id: int
    title: str
    company: str
    location: str
    description: Optional[str] = None
    link: str
    applied: bool
    score: float

    class Config:
        from_attributes = True