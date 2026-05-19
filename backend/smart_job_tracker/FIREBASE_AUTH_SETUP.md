# Firebase Authentication Integration Guide

## Overview

Production-ready Firebase Authentication for your FastAPI backend:
- ✅ Firebase token verification
- ✅ User sync to PostgreSQL/SQLite
- ✅ Protected routes with Bearer token authentication
- ✅ Reusable security dependency
- ✅ Scalable for saved jobs, alerts, notifications

---

## Architecture

```
CLIENT (Flutter/Web)
    │
    ├─→ User logs in with Firebase (Google, Email, etc)
    │
    └─→ Firebase returns ID Token (JWT)
        │
        └─→ POST /auth/sync-user (token)
            │
            └─→ Backend verifies token with Firebase
                ├─ Extract: uid, email, name
                ├─ Check if user exists in DB
                ├─ Create or update user
                └─ Return user profile
                │
                └─→ Client stores token locally
                │
                └─→ GET /users/me (with token)
                    │
                    └─→ Backend verifies token
                        ├─ Lookup user in DB
                        └─ Return authenticated user
```

---

## Setup Steps

### 1. Install Dependencies

```bash
pip install firebase-admin pydantic[email] python-dotenv
```

### 2. Download Firebase Credentials

1. Go to **Firebase Console** → Your Project
2. Click **Settings** (gear icon) → **Project Settings**
3. Go to **Service Accounts** tab
4. Click **Generate New Private Key**
5. Save as `smart-job-tracker-key.json` in project root
6. ⚠️ **Keep this file private!** Add to `.gitignore`:

```
smart-job-tracker-key.json
```

### 3. Create .env File

```bash
# Copy .env.example to .env
FIREBASE_KEY_PATH=smart-job-tracker-key.json
ENVIRONMENT=development
```

### 4. Database Migration

Run FastAPI once to create tables:

```bash
uvicorn app.main:app --reload
```

This creates the `users` table via SQLAlchemy.

---

## File Structure

```
app/
├── models.py                 # Updated with User model
├── schemas.py               # Updated with user schemas
├── dependencies.py          # Security dependency (get_auth_user)
├── services/
│   ├── __init__.py
│   ├── firebase_service.py  # Firebase initialization & token verification
│   └── user_service.py      # User sync & CRUD
└── main.py                  # Updated with auth endpoints
```

---

## API Endpoints

### 1. Sync User (After Firebase Login)

**Endpoint:** `POST /auth/sync-user`

**Request:**
```json
{
    "token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjEyMzQ1In0..."
}
```

**Response (201/200):**
```json
{
    "user": {
        "id": 1,
        "firebase_uid": "abc123xyz",
        "email": "user@gmail.com",
        "name": "John Doe",
        "created_at": "2026-05-02T10:30:00",
        "updated_at": "2026-05-02T10:30:00"
    },
    "message": "User synced successfully"
}
```

**Error (401):**
```json
{
    "detail": "Invalid Firebase token"
}
```

---

### 2. Get Current User (Protected)

**Endpoint:** `GET /users/me`

**Headers:**
```
Authorization: Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6IjEyMzQ1In0...
```

**Response (200):**
```json
{
    "id": 1,
    "firebase_uid": "abc123xyz",
    "email": "user@gmail.com",
    "name": "John Doe",
    "created_at": "2026-05-02T10:30:00",
    "updated_at": "2026-05-02T10:30:00"
}
```

**Error (401):**
```json
{
    "detail": "User abc123xyz not found in database. Please sync user first via /auth/sync-user"
}
```

---

## Testing with PowerShell

### 1. Test Sync User

```powershell
# Get Firebase token from client (login in Flutter/web app)
# Then use it like:

$token = "your_firebase_token_here"

$body = @{
    token = $token
} | ConvertTo-Json

Invoke-WebRequest -Method POST `
    -Uri "http://localhost:8000/auth/sync-user" `
    -ContentType "application/json" `
    -Body $body
```

### 2. Test Protected Route

```powershell
$token = "your_firebase_token_here"

Invoke-WebRequest `
    -Uri "http://localhost:8000/users/me" `
    -Headers @{Authorization = "Bearer $token"}
```

---

## Using Protected Routes in Your Code

### Example: Protect Any Endpoint

```python
from fastapi import Depends
from sqlalchemy.orm import Session
from .dependencies import get_auth_user
from .models import User
from .database import get_db

@app.post("/jobs/apply")
def apply_job(
    job_id: int,
    user: User = Depends(get_auth_user),  # ← Automatic auth check
    db: Session = Depends(get_db)
):
    """
    Apply to a job.
    Only authenticated users can call this.
    """
    # user is guaranteed to be valid User from DB
    return {
        "message": f"User {user.email} applied to job {job_id}"
    }
```

### Example: Save Job Application

```python
from sqlalchemy import Column, Integer, ForeignKey, DateTime, Boolean
from .database import Base
from sqlalchemy.sql import func

class JobApplication(Base):
    __tablename__ = "job_applications"
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))  # Link to User
    job_id = Column(Integer, ForeignKey("jobs.id"))
    applied_at = Column(DateTime, server_default=func.now())

# Then:
@app.post("/jobs/apply")
def apply_job(
    job_id: int,
    user: User = Depends(get_auth_user),
    db: Session = Depends(get_db)
):
    app = JobApplication(user_id=user.id, job_id=job_id)
    db.add(app)
    db.commit()
    return {"message": "Applied successfully"}
```

---

## Security Best Practices

✅ **Always use Bearer tokens** (HTTPS in production)  
✅ **Store token securely** in Flutter (use secure storage plugins)  
✅ **Tokens expire** (Firebase default: 1 hour)  
✅ **Refresh tokens** on client side when needed  
✅ **Never hardcode Firebase key** in code  
✅ **Use environment variables** for sensitive config  
✅ **Add rate limiting** for `/auth/sync-user` (optional)  

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `FileNotFoundError: smart-job-tracker-key.json` | Download from Firebase Console > Service Accounts |
| `Invalid Firebase token` | Token might be expired, ask client to re-login |
| `User not found in database` | Call `/auth/sync-user` first after login |
| `401 Unauthorized` | Check Authorization header format: `Bearer <token>` |

---

## Next Steps

1. ✅ Implement saved jobs tracking
2. ✅ Add job application history
3. ✅ Send notifications on new matching jobs
4. ✅ User preferences (location, skills, salary range)
5. ✅ Admin dashboard

---

## Code Examples by Use Case

### Save a Job

```python
from sqlalchemy import Boolean

class JobFavorite(Base):
    __tablename__ = "job_favorites"
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    job_id = Column(Integer, ForeignKey("jobs.id"))
    saved_at = Column(DateTime, server_default=func.now())

@app.post("/jobs/{job_id}/save")
def save_job(
    job_id: int,
    user: User = Depends(get_auth_user),
    db: Session = Depends(get_db)
):
    fav = JobFavorite(user_id=user.id, job_id=job_id)
    db.add(fav)
    db.commit()
    return {"message": "Job saved"}
```

### Get User's Saved Jobs

```python
@app.get("/jobs/saved")
def get_saved_jobs(
    user: User = Depends(get_auth_user),
    db: Session = Depends(get_db)
):
    favorites = db.query(JobFavorite).filter(
        JobFavorite.user_id == user.id
    ).all()
    return [fav.job_id for fav in favorites]
```

---

## Production Deployment Checklist

- [ ] Download & secure Firebase service account key
- [ ] Set `ENVIRONMENT=production` in .env
- [ ] Use PostgreSQL instead of SQLite
- [ ] Enable HTTPS (required for Firebase tokens)
- [ ] Add rate limiting to `/auth/sync-user`
- [ ] Set up monitoring/logging
- [ ] Test token refresh flow on client
- [ ] Document API for Flutter team
