from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from backend.config import settings

# SQLAlchemy 2.x maps a plain postgresql:// URL to the psycopg (v3) dialect,
# but the Docker image only installs psycopg2-binary, so a plain URL fails at
# startup with "ModuleNotFoundError: No module named 'psycopg'". Normalise the
# scheme here so the app works with either form, even if DATABASE_URL is ever
# reset to plain postgresql:// in Render.
_DATABASE_URL = settings.DATABASE_URL
if _DATABASE_URL.startswith("postgresql://"):
    _DATABASE_URL = _DATABASE_URL.replace(
        "postgresql://", "postgresql+psycopg2://", 1
    )

connect_args = {}
if settings.DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(
    _DATABASE_URL,
    connect_args=connect_args,
    # Neon closes idle connections after a few minutes; without this the
    # first request on a stale pooled connection fails with
    # "SSL connection has been closed unexpectedly" (seen 2026-11-17 on
    # POST /auth/register). pool_pre_ping tests the connection before use
    # and reconnects transparently.
    pool_pre_ping=True,
    echo=settings.DEBUG if settings.APP_ENV == "development" else False,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
