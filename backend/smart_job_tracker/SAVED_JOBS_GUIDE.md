# Saved Jobs & Firebase User Linking Guide

## Overview

This guide explains how the saved jobs functionality works and how Firebase users are linked to database records.

---

## 1. Firebase User Linking Strategy

### How It Works

1. **Flutter Frontend User Logs In**
   - User signs in with Firebase (Google, Email, etc.)
   - Firebase returns an ID token
   - Flutter app stores this token locally

2. **First API Call - Sync User**
   - Frontend calls `POST /auth/sync-user` with Firebase ID token
   - Backend:
     - Verifies the token with Firebase Admin SDK
     - Extracts `firebase_uid`, `email`, `name` from token
     - Checks if user already exists in DB
     - Creates or updates user record
     - Returns user data with database `id`

3. **Subsequent Requests - Authenticated Access**
   - All protected endpoints require Firebase ID token in Authorization header
   - Backend uses token to:
     - Verify token validity with Firebase
     - Extract `firebase_uid`
     - Look up user in database by `firebase_uid`
     - Return user data to route

### Database Linking

```
Firebase Auth      Database
(Cloud)            (Local SQLite)
│                  │
├─ uid              ├─ users.firebase_uid ← Links to Firebase
├─ email     ────→  ├─ users.email
├─ name      ────→  ├─ users.name
│                   ├─ users.id (Primary Key)
│                   │
│                   └─ saved_jobs.user_id ← Foreign Key
```

**Key Field**: `users.firebase_uid` - This is the unique identifier linking your Firebase user to database records.

---

## 2. Database Schema

### Users Table
```
users
├─ id (PK)              - Database primary key
├─ firebase_uid (UQ)    - Firebase UID (links to Firebase Auth)
├─ email (UQ)           - User email
├─ name                 - User name
├─ created_at           - Registration timestamp
└─ updated_at           - Last update timestamp
```

### Jobs Table
```
jobs
├─ id (PK)              - Database primary key
├─ title                - Job title
├─ company              - Company name
├─ location             - Job location
├─ link (UQ)            - Job URL
├─ description          - Job description
├─ applied              - Has user applied?
└─ created_at           - When job was added
```

### SavedJobs Table (NEW)
```
saved_jobs
├─ id (PK)              - Primary key
├─ user_id (FK)         - Links to users.id
├─ job_id (FK)          - Links to jobs.id
└─ created_at           - When job was saved
```

**Why separate table?**
- One user can save multiple jobs (1:N relationship)
- One job can be saved by multiple users (N:M relationship)
- `saved_jobs` is the junction table connecting them

---

## 3. API Endpoints

### Authentication Endpoints

#### **POST `/auth/sync-user`** (No Auth Required)
Sync Firebase user to database.

**Request:**
```json
{
  "token": "<firebase_id_token>"
}
```

**Response:**
```json
{
  "user": {
    "id": 1,
    "firebase_uid": "abc123xyz",
    "email": "user@example.com",
    "name": "John Doe",
    "created_at": "2026-05-16T...",
    "updated_at": "2026-05-16T..."
  },
  "message": "User synced successfully"
}
```

**Usage in Flutter:**
```dart
// After Firebase login
final idToken = await FirebaseAuth.instance.currentUser!.getIdToken();
final response = await http.post(
  Uri.parse('http://your-api.com/auth/sync-user'),
  body: jsonEncode({'token': idToken}),
);
```

---

#### **GET `/users/me`** (Auth Required)
Get current user profile.

**Headers:**
```
Authorization: Bearer <firebase_id_token>
```

**Response:**
```json
{
  "id": 1,
  "firebase_uid": "abc123xyz",
  "email": "user@example.com",
  "name": "John Doe",
  "created_at": "2026-05-16T...",
  "updated_at": "2026-05-16T..."
}
```

---

### Saved Jobs Endpoints

#### **POST `/jobs/save`** (Auth Required)
Save a job.

**Request:**
```json
{
  "job_id": 123
}
```

**Response:**
```json
{
  "saved": true,
  "message": "Job saved successfully",
  "saved_job_id": 1
}
```

**Errors:**
- `400 Bad Request` - Job already saved
- `400 Bad Request` - Job doesn't exist
- `401 Unauthorized` - Invalid token

---

#### **POST `/jobs/unsave`** (Auth Required)
Remove a saved job.

**Request:**
```json
{
  "job_id": 123
}
```

**Response:**
```json
{
  "unsaved": true,
  "message": "Job unsaved successfully"
}
```

**Errors:**
- `404 Not Found` - Saved job not found
- `401 Unauthorized` - Invalid token

---

#### **GET `/users/me/saved-jobs`** (Auth Required)
Get all saved jobs for current user.

**Query Parameters:**
- `limit` (int, default: 50, max: 100) - Results per page
- `offset` (int, default: 0) - Pagination offset

**Response:**
```json
[
  {
    "id": 1,
    "job_id": 123,
    "user_id": 1,
    "created_at": "2026-05-16T...",
    "job": {
      "id": 123,
      "title": "Senior Developer",
      "company": "TechCorp",
      "location": "Karachi",
      "link": "https://...",
      "description": "...",
      "applied": false,
      "created_at": "2026-05-15T..."
    }
  }
]
```

---

#### **GET `/jobs/{job_id}/is-saved`** (Auth Required)
Check if a job is saved by current user.

**Response:**
```json
{
  "saved": true
}
```

---

## 4. Flutter Implementation Example

### Step 1: User Registration/Login
```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final _auth = FirebaseAuth.instance;
const String API_URL = 'http://your-api.com';

Future<void> loginWithGoogle() async {
  try {
    // Firebase login
    final result = await _auth.signInWithPopup(GoogleAuthProvider());
    final user = result.user!;
    final idToken = await user.getIdToken();
    
    // Sync with backend
    final response = await http.post(
      Uri.parse('$API_URL/auth/sync-user'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': idToken}),
    );
    
    if (response.statusCode == 200) {
      print('User synced: ${response.body}');
    }
  } catch (e) {
    print('Login error: $e');
  }
}
```

### Step 2: Save a Job
```dart
Future<void> saveJob(int jobId) async {
  try {
    final idToken = await _auth.currentUser!.getIdToken();
    
    final response = await http.post(
      Uri.parse('$API_URL/jobs/save'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'job_id': jobId}),
    );
    
    if (response.statusCode == 200) {
      print('Job saved!');
    } else if (response.statusCode == 400) {
      print('Job already saved or not found');
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

### Step 3: Get Saved Jobs
```dart
Future<List<Map>> getSavedJobs() async {
  try {
    final idToken = await _auth.currentUser!.getIdToken();
    
    final response = await http.get(
      Uri.parse('$API_URL/users/me/saved-jobs?limit=50&offset=0'),
      headers: {
        'Authorization': 'Bearer $idToken',
      },
    );
    
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return List<Map>.from(data);
    }
  } catch (e) {
    print('Error: $e');
  }
  return [];
}
```

### Step 4: Check if Job is Saved
```dart
Future<bool> isJobSaved(int jobId) async {
  try {
    final idToken = await _auth.currentUser!.getIdToken();
    
    final response = await http.get(
      Uri.parse('$API_URL/jobs/$jobId/is-saved'),
      headers: {
        'Authorization': 'Bearer $idToken',
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['saved'] ?? false;
    }
  } catch (e) {
    print('Error: $e');
  }
  return false;
}
```

### Step 5: Unsave a Job
```dart
Future<void> unsaveJob(int jobId) async {
  try {
    final idToken = await _auth.currentUser!.getIdToken();
    
    final response = await http.post(
      Uri.parse('$API_URL/jobs/unsave'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'job_id': jobId}),
    );
    
    if (response.statusCode == 200) {
      print('Job unsaved!');
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

---

## 5. Authentication Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      FLUTTER APP                                │
│  (User signs in with Firebase)                                  │
└─────────────────────────────────────────────────────────────────┘
                         │
                         │ Firebase ID Token
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                      FastAPI Backend                            │
│                                                                 │
│  1. POST /auth/sync-user                                        │
│     - Verify token with Firebase Admin SDK                      │
│     - Extract uid, email, name                                  │
│     - Save/update user in DB with firebase_uid                 │
│     - Return user data                                          │
│                                                                 │
│  2. Protected Endpoints (Bearer token required)                 │
│     - GET /users/me (get user by firebase_uid)                 │
│     - POST /jobs/save (save job for user)                       │
│     - GET /users/me/saved-jobs (get saved jobs)                 │
└─────────────────────────────────────────────────────────────────┘
                         │
                         │ User Data + Saved Jobs
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                    SQLite Database                              │
│                                                                 │
│  users             saved_jobs      jobs                         │
│  ├─ id ───────┐    ├─ user_id ──┐  ├─ id                        │
│  ├─ firebase_ │    │   (FK)     │  ├─ title                     │
│    uid        │    ├─ job_id ───┼─→├─ company                   │
│  ├─ email     │    │   (FK)     │  ├─ location                  │
│  ├─ name      │    └────────────┘  ├─ link                      │
│  └────────────┘                     └─ description              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Important Notes

### For Flutter Developers

1. **Always call `/auth/sync-user` first** after Firebase login
2. **Store the Firebase ID token** for subsequent API calls
3. **Refresh the token** before it expires (typically hourly)
4. **Use Bearer token** in Authorization header

```dart
// Example: Refresh and retry
if (response.statusCode == 401) {
  final newToken = await _auth.currentUser!.getIdToken(force: true);
  // Retry request with new token
}
```

### For Backend Developers

1. **`firebase_uid` is the primary link** between Firebase and DB
2. **Do NOT rely on email** for user identity (can be updated)
3. **Use `get_auth_user` dependency** for all protected routes
4. **Always verify tokens** with Firebase before trusting claims

### Data Integrity

- Deleting a user cascades deletes all their saved jobs
- Deleting a job cascades deletes all saved records
- Unique constraint prevents duplicate saves
- Email is kept unique but shouldn't be used for queries

---

## 7. Testing with cURL

### Sync User
```bash
curl -X POST http://localhost:8000/auth/sync-user \
  -H "Content-Type: application/json" \
  -d '{"token": "<firebase_id_token>"}'
```

### Get Current User
```bash
curl -X GET http://localhost:8000/users/me \
  -H "Authorization: Bearer <firebase_id_token>"
```

### Save Job
```bash
curl -X POST http://localhost:8000/jobs/save \
  -H "Authorization: Bearer <firebase_id_token>" \
  -H "Content-Type: application/json" \
  -d '{"job_id": 123}'
```

### Get Saved Jobs
```bash
curl -X GET "http://localhost:8000/users/me/saved-jobs?limit=50&offset=0" \
  -H "Authorization: Bearer <firebase_id_token>"
```

---

## 8. Environment Setup

Make sure `.env` has Firebase configuration:

```
# Firebase Configuration
FIREBASE_KEY_PATH=smart-job-tracker-key.json
```

Download your service account key from Firebase Console:
1. Go to Firebase Console
2. Project Settings → Service Accounts
3. Click "Generate New Private Key"
4. Save as `smart-job-tracker-key.json` in project root

---

## Summary

✅ **Firebase users are linked via `firebase_uid`**
✅ **SavedJob table uses proper foreign keys**
✅ **All endpoints are protected with Bearer token auth**
✅ **Flutter can call endpoints with Firebase ID tokens**
✅ **Cascade delete ensures data integrity**

