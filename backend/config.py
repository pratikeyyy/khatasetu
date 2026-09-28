import os
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    APP_NAME: str = "KhataSetu"
    APP_ENV: str = "development"
    DEBUG: bool = True
    PORT: int = 8000
    HOST: str = "0.0.0.0"

    # Database
    DATABASE_URL: str = "sqlite:///./khatasetu.db"

    # Security
    JWT_SECRET: str = "khatasetu_super_secret_jwt_key_kirana_2026_production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 30  # 30 days session persistence

    # AI / Vision
    GEMINI_API_KEY: Optional[str] = None
    GEMINI_MODEL: str = "gemini-1.5-flash"

    # OCR Confidence Thresholds (0.0 to 1.0)
    CONFIDENCE_HIGH_THRESHOLD: float = 0.95
    CONFIDENCE_REVIEW_THRESHOLD: float = 0.80

    # Storage
    UPLOAD_DIR: str = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "uploads")
    MAX_IMAGE_SIZE_MB: int = 10

    # Firebase
    FIREBASE_PROJECT_ID: Optional[str] = None
    FIREBASE_STORAGE_BUCKET: Optional[str] = None

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
