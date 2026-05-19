# How to Run Celery + Redis Setup

## Step 1: Verify Setup is Working
```bash
python test_celery_redis.py
```
You should see:
```
✅ Redis is running at localhost:6379
✅ Redis SET/GET working: test_value
✅ Celery app loaded
✅ Task sent! Task ID: abc123def456
```

If Redis fails, start it first:
- **Windows (WSL):** `wsl redis-server`
- **Windows (Native):** Download from https://github.com/microsoftarchive/redis/releases

---

## Step 2: Open 4 Terminal Windows

### Terminal 1 - Start Redis (if not running)
```bash
wsl redis-server
```
You should see:
```
* Ready to accept connections
```

### Terminal 2 - Start Celery Worker
```bash
celery -A app.celery_worker worker --loglevel=info --pool=solo
```
You should see:
```
[CELERY] Initialized with Redis broker/backend
celery@YOUR-MACHINE ready to accept tasks
```

### Terminal 3 - Start Celery Beat (Optional - for 24h schedule)
```bash
celery -A app.celery_worker celery_app beat --loglevel=info
```
You should see:
```
beat: Starting...
beat: Scheduler: celery.beat.PersistentScheduler
```

### Terminal 4 - Start FastAPI
```bash
uvicorn app.main:app --reload
```
You should see:
```
Uvicorn running on http://127.0.0.1:8000
```

---

## Step 3: Test It's Working

### Option A: Using API (Recommended)

**Trigger scraping:**
```bash
curl -X POST http://localhost:8000/scrape/
```
Response:
```json
{"status": "Scraping queued", "task_id": "abc123..."}
```

**Check task status:**
```bash
curl http://localhost:8000/task-status/abc123...
```
Response while running:
```json
{"task_id": "abc123...", "status": "STARTED", "result": null, "error": null}
```

Response when done:
```json
{
  "task_id": "abc123...",
  "status": "SUCCESS",
  "result": {"saved": 5, "skipped": 3},
  "error": null
}
```

### Option B: Watch Terminal 2 (Worker)
You should see prints like:
```
[TASK] 🚀 scrape_jobs_task started
[TASK] ✅ scrape_jobs_task completed: {'saved': 5, 'skipped': 3}
```

---

## How to Know It's Working

### ✅ Good Signs:
1. **Redis**: `[CELERY] Initialized with Redis broker/backend` prints in worker
2. **Worker**: `celery@YOUR-MACHINE ready to accept tasks` appears
3. **Task queued**: `📤 Task queued: abc123...` prints in FastAPI terminal
4. **Task running**: `[TASK] 🚀 scrape_jobs_task started` appears in worker terminal
5. **Task done**: Task status changes from `PENDING` → `STARTED` → `SUCCESS`

### ❌ Problems:
| Error | Solution |
|-------|----------|
| `ConnectionRefusedError: Connection refused` | Redis not running - start it |
| `Worker doesn't process tasks` | Worker not started - run Terminal 2 |
| `Task state stays PENDING` | No worker listening - check Terminal 2 |
| `FAILURE status` | Check worker terminal for errors |

---

## Daily 24-hour Scheduling

The `celery_worker.py` already has:
```python
beat_schedule = {
    "run-scraper-every-24-hours": {
        "task": "scrape_jobs_task",
        "schedule": crontab(hour=0, minute=0),  # Runs at midnight daily
    },
}
```

Just keep **Terminal 3 (Celery Beat)** running to enable automatic scheduling.

---

## Quick Troubleshooting Checklist

- [ ] Redis running? Check: `redis-cli ping` → should return `PONG`
- [ ] Worker running? Look for `ready to accept tasks` in Terminal 2
- [ ] Database writable? Check if `smart_job_tracker.db` exists and has no errors
- [ ] Scrapers working? Check if they return jobs before Celery setup
- [ ] Port 8000 free? Use different port: `uvicorn app.main:app --port 8001`
