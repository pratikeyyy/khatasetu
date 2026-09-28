# KhataSetu (खातासेतु)
> **"From Paper Khata to Smart Digital Khata"**

KhataSetu is an AI-powered digital ledger and khata app tailored specifically for Indian kirana store and small business owners. Its core breakthrough feature enables shopkeepers to photograph handwritten paper registers/bahi-khatas. The image is passed through an OCR/Vision pipeline (powered by Google Gemini Vision), extracting customer names, transaction amounts, transaction types (Udhar/Jama), dates, and notes, complete with confidence scores and a human-in-the-loop review workflow.

---

## 🌟 Key Features

1. **AI Vision & Extraction Pipeline:**
   - Preprocesses paper register photos (contrast enhancement, deskew, EXIF correction).
   - Extracts ledger entries using Google Gemini Vision with deterministic JSON schema.
   - Computes weighted confidence scores ($Amount: 40\%$, $Name: 35\%$, $Date: 15\%$, $Type: 10\%$).
   - Safety rule: If amount or name confidence $< 0.80$, overall confidence is capped at $0.79$, preventing financial false-positives.

2. **Human-in-the-Loop Review System:**
   - **HIGH ($\ge 0.95$):** Auto-confirmable with 1-click batch confirmation.
   - **NEEDS REVIEW ($0.80 - 0.94$):** Highlighted in amber, shopkeeper can inline edit and confirm.
   - **MANUAL VERIFICATION ($< 0.80$):** Mandatory shopkeeper inspection.
   - Complete audit trail logging who verified or modified every extracted entry.

3. **Intelligent Customer Matching:**
   - Token-overlap and Levenshtein distance fuzzy matching.
   - Automatic stripping of Indian honorifics (*bhai, ji, saheb, seth, babu, uncle*).
   - Automatic customer creation or duplicate resolution.

4. **Zero-Cost WhatsApp Reminders:**
   - Zero-dependency payment reminders via direct `wa.me` deep links (no Twilio, zero API cost).
   - Multilingual message templates: Hindi, Hinglish, and English.

5. **Duplicate Transaction Protection:**
   - 24-hour duplicate transaction safety check with shopkeeper override (`force=True`).

6. **Real-Time Kirana Financial Analytics:**
   - Total outstanding, daily credit, daily payments, and 7/30-day cashflow charts.

---

## 🏗️ Architecture

```
khataSetu/
├── backend/                  # FastAPI 0.111+ Python Backend
│   ├── models/               # SQLAlchemy ORM (SQLite / PostgreSQL)
│   ├── schemas/              # Pydantic v2 validation models
│   ├── routers/              # REST API endpoints (Auth, Scans, Ledger, Customers)
│   ├── services/             # Gemini Vision OCR, Confidence, Matching, Reminders
│   ├── tests/                # Pytest test suite (17 Unit & Integration tests)
│   └── seed.py               # Database seeder with realistic Kirana data
├── frontend/                 # Flutter 3.x Mobile & Web App
│   └── lib/
│       ├── core/             # Themes, GoRouter navigation, Dio API Client, LocalStorage
│       ├── models/           # Dart data models with JSON serialization
│       ├── providers/        # State management via Riverpod
│       ├── widgets/          # Reusable UI (ConfidenceBadge, KpiCard, WhatsAppDialog)
│       └── screens/          # 11 complete application screens
└── dataset/                  # Synthetic training/testing Khata dataset & eval scripts
```

---

## 🚀 Quick Start Guide

### 1. Backend Setup

```powershell
cd d:\khatasetu

# Activate Python virtual environment
.\venv\Scripts\activate

# Install dependencies (already present in requirements.txt)
pip install -r requirements.txt

# Seed the database
python backend/seed.py

# Run the development backend server
uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```
- Swagger API Docs: `http://localhost:8000/docs`
- Default Demo Login: `shopkeeper@khatasetu.com` / `password123`

### 2. Frontend Setup (Flutter)

```powershell
cd d:\khatasetu\frontend

# Fetch Flutter dependencies
flutter pub get

# Run on Chrome/Web
flutter run -d chrome

# Run on Android Emulator/Device
flutter run
```

---

## 🧪 Running Automated Tests

```powershell
pytest -v backend/tests
```
All 17 integration and unit tests pass with zero failures.

---

## 📜 License
MIT License. Built with ❤️ for Kirana shop owners.
