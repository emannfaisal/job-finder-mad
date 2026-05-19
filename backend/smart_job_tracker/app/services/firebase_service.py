"""
Firebase Admin SDK initialization and token verification.
Handles Firebase authentication operations.
"""

import firebase_admin
from firebase_admin import credentials, auth
import os
import logging
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

FIREBASE_KEY_PATH = os.getenv("FIREBASE_KEY_PATH", "smart-job-tracker-key.json")


def initialize_firebase():
    """Initialize Firebase Admin SDK once at app startup."""
    try:
        # Check if Firebase app is already initialized
        try:
            firebase_admin.get_app()
            logger.info("[FIREBASE] ℹ️ Firebase already initialized")
        except ValueError:
            # App not initialized yet, so initialize it
            cred = credentials.Certificate(FIREBASE_KEY_PATH)
            firebase_admin.initialize_app(cred)
            logger.info("[FIREBASE] ✅ Firebase Admin SDK initialized")
    except FileNotFoundError:
        logger.warning(
            f"[FIREBASE] ⚠️ Credentials file not found: {FIREBASE_KEY_PATH}\n"
            "           Firebase authentication will be unavailable.\n"
            "           Download from Firebase Console > Project Settings > Service Accounts\n"
            "           and place it in the project root to enable Firebase features."
        )
        # Don't raise - allow app to start without Firebase
    except Exception as e:
        logger.warning(f"[FIREBASE] ⚠️ Initialization warning: {e}\n"
                      "Firebase authentication will be unavailable.")


def verify_firebase_token(token: str) -> dict:
    """
    Verify Firebase ID token and decode user information.
    
    Args:
        token: Firebase ID token from client
        
    Returns:
        dict: Decoded token with uid, email, name, etc.
        
    Raises:
        ValueError: If token is invalid/expired
    """
    try:
        decoded_token = auth.verify_id_token(token)
        uid = decoded_token.get("uid")
        logger.info(f"[FIREBASE] ✅ Token verified for user: {uid}")
        return decoded_token
    except ValueError as e:
        if "default Firebase app does not exist" in str(e):
            raise ValueError("Firebase is not configured. Contact administrator.")
        raise ValueError("Invalid Firebase token")
    except auth.InvalidIdTokenError as e:
        logger.error(f"[FIREBASE] ❌ Invalid token: {e}")
        raise ValueError("Invalid Firebase token")
    except auth.ExpiredIdTokenError as e:
        logger.error(f"[FIREBASE] ❌ Token expired: {e}")
        raise ValueError("Firebase token has expired")
    except Exception as e:
        logger.error(f"[FIREBASE] ❌ Token verification failed: {e}")
        raise ValueError(f"Token verification failed: {str(e)}")


def get_firebase_user(uid: str):
    """
    Get Firebase user by UID.
    
    Args:
        uid: Firebase user ID
        
    Returns:
        Firebase UserRecord
    """
    try:
        user = auth.get_user(uid)
        return user
    except auth.UserNotFoundError:
        logger.error(f"[FIREBASE] ❌ User not found: {uid}")
        return None
    except Exception as e:
        logger.error(f"[FIREBASE] ❌ Error getting user: {e}")
        return None
