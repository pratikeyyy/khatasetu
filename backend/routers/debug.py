import os
import platform
import datetime
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text, desc

from backend.config import settings
from backend.database import get_db
from backend.models.scan import Scan
from backend.models.audit import AuditLog

router = APIRouter(prefix="/debug", tags=["Developer & Diagnostics"])


@router.get("/status")
def get_system_status(db: Session = Depends(get_db)):
    # 1. Database connection check
    db_status = "healthy"
    try:
        db.execute(text("SELECT 1"))
    except Exception as e:
        db_status = f"unhealthy: {str(e)}"

    # 2. Gemini status check (without exposing key)
    gemini_configured = bool(settings.GEMINI_API_KEY and settings.GEMINI_API_KEY.strip())
    gemini_status = {
        "configured": gemini_configured,
        "mode": "Live Gemini Vision" if gemini_configured else "Deterministic Kirana Mock (Offline Demo)",
        "model": settings.GEMINI_MODEL,
        "high_confidence_threshold": settings.CONFIDENCE_HIGH_THRESHOLD,
        "review_threshold": settings.CONFIDENCE_REVIEW_THRESHOLD,
    }

    # 3. Storage check
    upload_dir_exists = os.path.exists(settings.UPLOAD_DIR)
    upload_count = len(os.listdir(settings.UPLOAD_DIR)) if upload_dir_exists else 0

    # 4. Last scan diagnostics
    last_scan = db.query(Scan).order_by(desc(Scan.created_at)).first()
    last_scan_info = None
    if last_scan:
        last_scan_info = {
            "id": last_scan.id,
            "status": last_scan.status,
            "total_entries": last_scan.total_entries,
            "confirmed_entries": last_scan.confirmed_entries,
            "high_confidence_entries": last_scan.high_confidence_entries,
            "processing_time_ms": last_scan.processing_time_ms,
            "created_at": last_scan.created_at.isoformat() if last_scan.created_at else None,
        }

    # 5. Recent audit logs count
    recent_audits = db.query(AuditLog).order_by(desc(AuditLog.timestamp)).limit(5).all()
    audit_previews = [
        {"action": a.action, "summary": a.change_summary, "timestamp": a.timestamp.isoformat()}
        for a in recent_audits
    ]

    return {
        "app_name": settings.APP_NAME,
        "environment": settings.APP_ENV,
        "system": {
            "platform": platform.platform(),
            "python_version": platform.python_version(),
            "server_time": datetime.datetime.utcnow().isoformat(),
        },
        "database": {
            "status": db_status,
            "type": "SQLite (Development)" if settings.DATABASE_URL.startswith("sqlite") else "PostgreSQL",
        },
        "ai_pipeline": gemini_status,
        "storage": {
            "upload_dir_accessible": upload_dir_exists,
            "stored_files_count": upload_count,
        },
        "last_scan_diagnostics": last_scan_info,
        "recent_audit_events": audit_previews,
    }
