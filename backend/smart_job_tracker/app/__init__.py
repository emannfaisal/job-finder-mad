"""
Smart Job Tracker Application
Scrapes jobs from multiple sources and stores them in a database.
"""

from .main import app
from .database import init_db

__version__ = "1.0.0"
