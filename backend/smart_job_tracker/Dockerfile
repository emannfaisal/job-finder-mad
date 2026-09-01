# Use official Playwright Python image pre-configured with Chromium browser dependencies
FROM mcr.microsoft.com/playwright/python:v1.48.0-jammy

# Set working directory inside container
WORKDIR /app

# Prevent Python from writing .pyc files and enable unbuffered output
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install Playwright Chromium browser binary
RUN playwright install chromium

# Copy application source code
COPY . .

# Expose default port
EXPOSE 8000

# Default command to start FastAPI
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

