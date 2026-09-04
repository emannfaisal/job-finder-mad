"""
Firebase Admin SDK initialization and token verification.
Handles Firebase authentication operations.
"""

import json
import firebase_admin
from firebase_admin import credentials, auth
import os
import logging

from app.config import load_environment

load_environment()
logger = logging.getLogger(__name__)

FIREBASE_KEY_PATH = os.getenv("FIREBASE_KEY_PATH")
FIREBASE_CREDENTIALS_JSON = os.getenv("FIREBASE_CREDENTIALS_JSON")


def initialize_firebase():
    """Initialize Firebase Admin SDK once at app startup."""
    try:
        # Check if Firebase app is already initialized
        try:
            firebase_admin.get_app()
            logger.info("[FIREBASE] ℹ️ Firebase already initialized")
            return
        except ValueError:
            pass

        cred = None
        # 1. Try loading from FIREBASE_CREDENTIALS_JSON env var (recommended for production)
        if FIREBASE_CREDENTIALS_JSON:
            try:
                cert_dict = json.loads(FIREBASE_CREDENTIALS_JSON)
                cred = credentials.Certificate(cert_dict)
                logger.info("[FIREBASE] ✅ Initializing Firebase from FIREBASE_CREDENTIALS_JSON env var")
            except Exception as e:
                logger.error(f"[FIREBASE] ❌ Error parsing FIREBASE_CREDENTIALS_JSON: {e}")

        # 2. Fallback to FIREBASE_KEY_PATH file (local development)
        if not cred and FIREBASE_KEY_PATH:
            if os.path.exists(FIREBASE_KEY_PATH):
                cred = credentials.Certificate(FIREBASE_KEY_PATH)
                logger.info(f"[FIREBASE] ✅ Initializing Firebase from file: {FIREBASE_KEY_PATH}")
            else:
                logger.warning(f"[FIREBASE] ⚠️ File not found at FIREBASE_KEY_PATH: {FIREBASE_KEY_PATH}")

        if cred:
            firebase_admin.initialize_app(cred)
            logger.info("[FIREBASE] ✅ Firebase Admin SDK initialized successfully")
        else:
            logger.warning(
                "[FIREBASE] ⚠️ Firebase credentials not configured. "
                "Set FIREBASE_CREDENTIALS_JSON or FIREBASE_KEY_PATH in your environment."
            )
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
