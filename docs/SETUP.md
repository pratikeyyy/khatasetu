# KhataSetu — Setup and Installation Guide

## 1. Prerequisites
- **Python**: 3.11 or 3.12 (Installed at `C:\Users\pk713\AppData\Local\Programs\Python\Python312\`)
- **Flutter SDK**: 3.22+ or 3.44+ (Available at `D:\flutter_windows_3.44.9-stable\flutter\bin`)
- **Git**: 2.40+ (Installed at `D:\Git\cmd`)
- **SQLite3**: Bundled with Python (or PostgreSQL 15+ for production)

---

## 2. Environment Variables (.env)

A template is provided at `.env.example`. Create a `.env` in the project root:

```ini
APP_NAME=KhataSetu
APP_ENV=development
DEBUG=True
SECRET_KEY=khatasetu_super_secret_jwt_key_change_in_production_2026
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080

# Database Configuration
DATABASE_URL=sqlite:///./khatasetu.db

# Storage
UPLOAD_DIR=./uploads

# AI Vision / OCR
# Leave blank to use realistic deterministic Kirana mock engine
GEMINI_API_KEY=
GEMINI_MODEL=gemini-1.5-flash
```

---

## 3. Backend Step-by-Step

```powershell
cd d:\khatasetu

# 1. Create and activate virtual environment (if not already existing)
python -m venv venv
.\venv\Scripts\activate

# 2. Install requirements
pip install -r requirements.txt

# 3. Seed initial database with sample shop, customers, and ledger
python backend/seed.py

# 4. Run tests to verify setup
pytest -v backend/tests

# 5. Start development server
uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

---

## 4. Frontend Step-by-Step (Flutter)

```powershell
cd d:\khatasetu\frontend

# Ensure flutter is on PATH or call directly
D:\flutter_windows_3.44.9-stable\flutter\bin\flutter.bat pub get

# Launch on Chrome
D:\flutter_windows_3.44.9-stable\flutter\bin\flutter.bat run -d chrome

# Launch on connected Android device / emulator
D:\flutter_windows_3.44.9-stable\flutter\bin\flutter.bat run
```

---

## 5. Synthetic Dataset Generation & OCR Evaluation

```powershell
cd d:\khatasetu

# Generate 10 synthetic handwritten-style khata register images
python dataset/generate_synthetic.py

# Run evaluation suite on generated dataset
python dataset/evaluate.py
```
