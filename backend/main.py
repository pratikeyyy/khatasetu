import os
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse

from backend.config import settings
from backend.database import Base, engine, SessionLocal
from backend.services.matching_service import MatchingService
from backend.models.shop import Shop
from backend.routers import (
    auth_router,
    shops_router,
    customers_router,
    transactions_router,
    scans_router,
    dashboard_router,
    reminders_router,
    reports_router,
    debug_router,
)

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("KhataSetu")


import asyncio

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Ensure DB tables exist
    logger.info("Initializing database tables...")
    # TODO: In production, Alembic should be used for migrations.
    Base.metadata.create_all(bind=engine)
    
    if settings.APP_ENV == "production" and settings.JWT_SECRET == "khatasetu_super_secret_jwt_key_kirana_2026_production":
        raise RuntimeError("CRITICAL: JWT_SECRET must be overridden in production!")

    def repair_task():
        db = SessionLocal()
        try:
            shop_ids = [row[0] for row in db.query(Shop.id).all()]
            repaired = 0
            for shop_id in shop_ids:
                repaired += MatchingService.repair_ai_transaction_links(db, shop_id)
            if repaired:
                logger.info("Repaired %s AI transaction/customer links.", repaired)
        except Exception:
            logger.exception("AI transaction/customer repair skipped.")
            db.rollback()
        finally:
            db.close()

    # Run repair without blocking startup
    loop = asyncio.get_running_loop()
    loop.run_in_executor(None, repair_task)

    logger.info("KhataSetu backend initialized successfully.")
    yield
    # Shutdown
    logger.info("KhataSetu backend shutting down...")


app = FastAPI(
    title=settings.APP_NAME,
    description="From Paper Khata to Smart Digital Khata — AI Vision OCR, Ledger Management & Deep Link Reminders",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS Middleware for Flutter mobile, web, and local dev
origins_str = os.environ.get("CORS_ORIGINS", "*")
origins = origins_str.split(",") if origins_str else ["*"]
allow_all = "*" in origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=not allow_all,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static uploads directory for served ledger scan images
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

# Include API Routers under /api/v1
API_V1_PREFIX = "/api/v1"
app.include_router(auth_router, prefix=API_V1_PREFIX)
app.include_router(shops_router, prefix=API_V1_PREFIX)
app.include_router(customers_router, prefix=API_V1_PREFIX)
app.include_router(transactions_router, prefix=API_V1_PREFIX)
app.include_router(scans_router, prefix=API_V1_PREFIX)
app.include_router(dashboard_router, prefix=API_V1_PREFIX)
app.include_router(reminders_router, prefix=API_V1_PREFIX)
app.include_router(reports_router, prefix=API_V1_PREFIX)
app.include_router(debug_router, prefix=API_V1_PREFIX)


@app.get("/")
def root():
    return {
        "app": settings.APP_NAME,
        "tagline": "From Paper Khata to Smart Digital Khata",
        "status": "online",
        "docs": "/docs",
        "version": "1.0.0",
    }


# Friendly generic error handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception on {request.method} {request.url.path}: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "An unexpected error occurred while processing your request. Please try again or contact support."
        },
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
