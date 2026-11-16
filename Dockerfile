# KhataSetu backend — Render (Docker)
# Build context: repo root (pratikeyyy/khatasetu, branch master).
# Copies ONLY backend/ + the requirements file, so Flutter code is not in the image.
# NOTE: backend/requirements.txt is UTF-8 (fixed from UTF-16LE, which pip cannot parse)
# and uses psycopg2-binary (SQLAlchemy's postgresql:// dialect needs psycopg2, not psycopg v3).
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY backend/requirements.txt /tmp/requirements.txt
RUN pip install --upgrade pip \
    && pip install -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

COPY backend/ ./backend/

# Uploads dir must exist at import time (config.py also creates it).
RUN mkdir -p /app/uploads

EXPOSE 8000

# Render injects $PORT; default to 8000 for local `docker run`.
CMD ["sh", "-c", "uvicorn backend.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
