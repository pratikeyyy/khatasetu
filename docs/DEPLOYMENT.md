# KhataSetu — Production Deployment Guide

## Architecture Overview

```
                      +-----------------------------+
                      |   Mobile App (Flutter) /    |
                      |   Web Dashboard (Nginx)     |
                      +--------------+--------------+
                                     |
                             HTTPS (Port 443)
                                     v
                      +-----------------------------+
                      |   Reverse Proxy (Caddy/Nginx)|
                      +--------------+--------------+
                                     |
                              HTTP (Port 8000)
                                     v
                      +-----------------------------+
                      |   Uvicorn / Gunicorn Server |
                      |   FastAPI Backend           |
                      +--------------+--------------+
                                     |
                        +------------+------------+
                        |                         |
                        v                         v
               +-----------------+       +-----------------+
               | PostgreSQL 16   |       | Local / S3 /    |
               | Database Engine |       | GCS File Storage|
               +-----------------+       +-----------------+
```

---

## 1. Production Dockerfile (Backend)

```dockerfile
FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```

---

## 2. Docker Compose (`docker-compose.yml`)

```yaml
version: '3.8'

services:
  db:
    image: postgres:16-alpine
    restart: always
    environment:
      POSTGRES_USER: khatasetu_user
      POSTGRES_PASSWORD: production_strong_password
      POSTGRES_DB: khatasetu
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  backend:
    build: .
    restart: always
    depends_on:
      - db
    environment:
      - DATABASE_URL=postgresql://khatasetu_user:production_strong_password@db:5432/khatasetu
      - SECRET_KEY=generate_a_secure_random_64_character_hex_key
      - APP_ENV=production
      - DEBUG=False
      - GEMINI_API_KEY=${GEMINI_API_KEY}
    volumes:
      - ./uploads:/app/uploads
    ports:
      - "8000:8000"

volumes:
  postgres_data:
```

---

## 3. Flutter Web / Android Release Builds

### Web Release Build
```powershell
cd frontend
flutter build web --release --pwa-strategy=offline-first
# Static output generated at frontend/build/web
```

### Android APK Build
```powershell
cd frontend
flutter build apk --release --split-per-abi
# Output APK generated at frontend/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```
