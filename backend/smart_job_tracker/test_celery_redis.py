#!/usr/bin/env python
"""
Simple verification script to test Celery + Redis setup.
Run this to check if everything is connected properly.

Usage:
    python test_celery_redis.py
"""

import sys
import time

print("\n" + "="*60)
print("CELERY + REDIS VERIFICATION")
print("="*60)

# Test 1: Redis Connection
print("\n[1] Testing Redis connection...")
try:
    import redis
    r = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)
    r.ping()
    print("    ✅ Redis is running at localhost:6379")
    
    # Test set/get
    r.set('test_key', 'test_value', ex=10)
    val = r.get('test_key')
    print(f"    ✅ Redis SET/GET working: {val}")
    r.delete('test_key')
except ConnectionRefusedError:
    print("    ❌ Cannot connect to Redis on localhost:6379")
    print("       Start Redis first (WSL: wsl redis-server)")
    sys.exit(1)
except Exception as e:
    print(f"    ❌ Error: {e}")
    sys.exit(1)

# Test 2: Celery Import
print("\n[2] Testing Celery import...")
try:
    from app.celery_worker import celery_app, scrape_jobs_task
    print(f"    ✅ Celery app loaded")
    print(f"       Broker: {celery_app.conf.broker_url}")
    print(f"       Backend: {celery_app.conf.result_backend}")
except Exception as e:
    print(f"    ❌ Error importing Celery: {e}")
    sys.exit(1)

# Test 3: Send a test task
print("\n[3] Sending test task to Celery...")
try:
    # Send a simple task
    task = scrape_jobs_task.delay()
    print(f"    ✅ Task sent! Task ID: {task.id}")
    print(f"       Task state: {task.state}")
    print(f"       (Worker should process it in background)")
except Exception as e:
    print(f"    ❌ Error sending task: {e}")
    sys.exit(1)

print("\n" + "="*60)
print("✅ SETUP VERIFICATION COMPLETE!")
print("="*60)
print("""
Now run these commands in separate terminals:

Terminal 1 - Start Redis (if not running):
    wsl redis-server

Terminal 2 - Start Celery Worker (Windows: add --pool=solo):
    celery -A app.celery_worker worker --loglevel=info --pool=solo

Terminal 3 - Start Celery Beat (scheduler for 24h tasks):
    celery -A app.celery_worker beat --loglevel=info

Terminal 4 - Start FastAPI:
    uvicorn app.main:app --reload

Then trigger scrape via API:
    POST http://localhost:8000/scrape/
    
Check task status with task_id from response.
""")
print("="*60 + "\n")
