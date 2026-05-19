"""
FastAPI dependencies for authentication and authorization.
Reusable across all protected endpoints.
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer
from sqlalchemy.orm import Session
from .database import get_db
from .models import User
from .services.user_service import get_current_user_from_token
import logging

logger = logging.getLogger(__name__)

security = HTTPBearer()


async def get_auth_user(
    credentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    """
    Dependency to extract and verify current authenticated user from Firebase token.
    
    Use this in protected endpoints:
    
    Example:
        @app.get("/users/me")
        def get_me(user: User = Depends(get_auth_user)):
            return user
            
        @app.post("/jobs/save")
        def save_job(save_req: SaveJobRequest, user: User = Depends(get_auth_user)):
            # user is now authenticated
            ...
    
    Raises:
        HTTPException 401: If token invalid or user not in DB
    """
    token = credentials.credentials
    
    try:
        user = get_current_user_from_token(db, token)
        return user
    except ValueError as e:
        logger.error(f"[AUTH] ❌ Authentication failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        logger.error(f"[AUTH] ❌ Unexpected error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed",
            headers={"WWW-Authenticate": "Bearer"},
        )
