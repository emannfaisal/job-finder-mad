#!/usr/bin/env python
"""
Firebase Authentication Setup Verification Script.

Checks if Firebase is properly configured and working.

Usage:
    python verify_firebase_setup.py
"""

import sys
import os

print("\n" + "="*70)
print("FIREBASE AUTHENTICATION SETUP VERIFICATION")
print("="*70)

# Test 1: Check Firebase credentials file
print("\n[1] Checking Firebase credentials file...")
firebase_key = os.getenv("FIREBASE_KEY_PATH", "smart-job-tracker-key.json")

if os.path.exists(firebase_key):
    print(f"    ✅ Found: {firebase_key}")
else:
    print(f"    ❌ Not found: {firebase_key}")
    print("       Download from: Firebase Console > Project Settings > Service Accounts")
    sys.exit(1)

# Test 2: Check Firebase imports
print("\n[2] Testing Firebase Admin SDK import...")
try:
    import firebase_admin
    from firebase_admin import credentials, auth
    print("    ✅ firebase-admin installed and imported")
except ImportError:
    print("    ❌ firebase-admin not installed")
    print("       Run: pip install firebase-admin")
    sys.exit(1)

# Test 3: Initialize Firebase
print("\n[3] Initializing Firebase Admin SDK...")
try:
    from app.services.firebase_service import initialize_firebase
    initialize_firebase()
    print("    ✅ Firebase initialized successfully")
except Exception as e:
    print(f"    ❌ Error: {e}")
    print("       Make sure credentials file is valid")
    sys.exit(1)

# Test 4: Check database
print("\n[4] Checking database and User model...")
try:
    from app.database import init_db
    from app.models import User, Job
    init_db()
    print("    ✅ Database initialized")
    print("    ✅ User model available")
    print("    ✅ Job model available")
except Exception as e:
    print(f"    ❌ Error: {e}")
    sys.exit(1)

# Test 5: Check schemas
print("\n[5] Checking Pydantic schemas...")
try:
    from app.schemas import UserResponse, SyncUserRequest, SyncUserResponse
    print("    ✅ UserResponse schema available")
    print("    ✅ SyncUserRequest schema available")
    print("    ✅ SyncUserResponse schema available")
except ImportError:
    print("    ❌ pydantic[email] not installed")
    print("       Run: pip install 'pydantic[email]'")
    sys.exit(1)

# Test 6: Check dependencies
print("\n[6] Checking security dependencies...")
try:
    from app.dependencies import get_auth_user
    print("    ✅ get_auth_user dependency available")
except Exception as e:
    print(f"    ❌ Error: {e}")
    sys.exit(1)

# Test 7: Check services
print("\n[7] Checking authentication services...")
try:
    from app.services.firebase_service import verify_firebase_token
    from app.services.user_service import sync_user_from_firebase, get_current_user
    print("    ✅ Firebase service available")
    print("    ✅ User service available")
except Exception as e:
    print(f"    ❌ Error: {e}")
    sys.exit(1)

print("\n" + "="*70)
print("✅ FIREBASE SETUP VERIFICATION COMPLETE!")
print("="*70)
print("""
Next steps:

1. Get Firebase token from client:
   - Login to your Flutter/Web app with Firebase
   - Token is returned after successful authentication

2. Test sync endpoint:
   Invoke-WebRequest -Method POST \\
       -Uri "http://localhost:8000/auth/sync-user" \\
       -ContentType "application/json" \\
       -Body (@{token="YOUR_TOKEN"} | ConvertTo-Json)

3. Test protected endpoint:
   Invoke-WebRequest \\
       -Uri "http://localhost:8000/users/me" \\
       -Headers @{Authorization="Bearer YOUR_TOKEN"}

For detailed setup: See FIREBASE_AUTH_SETUP.md
""")
print("="*70 + "\n")
