# KhataSetu — Master Implementation Plan
**Tagline:** *"From Paper Khata to Smart Digital Khata"*  
**App Package:** `com.khatasetu.app`

KhataSetu is an AI-powered digital khata application tailored for Indian kirana and small business owners. Its core differentiator transforms handwritten paper khata register pages into verified digital transactions via a Gemini Vision OCR pipeline with strict confidence scoring, fuzzy customer matching, duplicate protection, complete audit trail, and zero-cost WhatsApp deep-link payment reminders.

---

## 1. System Architecture

```
                      ┌─────────────────────────────────────────┐
                      │          KhataSetu Architecture         │
                      └─────────────────────────────────────────┘

       ┌────────────────────────────────┐       ┌────────────────────────────────┐
       │     Flutter Mobile Frontend    │       │         FastAPI Backend        │
       │  - Material 3 Indian Kirana UI │       │  - Modular Clean Architecture  │
       │  - Riverpod State Management   │◄─────►│  - SQLite (Dev) / Postgres (Pr)│
       │  - GoRouter Navigation         │  REST │  - Pydantic v2 Strong Schemas  │
       │  - Camera & Image Preprocessing│  JSON │  - Gemini Vision API Pipeline  │
       │  - wa.me WhatsApp Reminders    │       │  - Field Confidence Engine     │
       │  - fl_chart Visual Analytics   │       │  - Audit Trail & Fuzzy Matcher │
       └────────────────────────────────┘       └────────────────────────────────┘
                       │                                         │
                       ▼                                         ▼
             Android / Web / Windows                   Gemini 1.5/2.0 Flash/Pro
                                                       Structured Ledger Vision
```

---

## 2. Technical Stack

| Layer | Technologies |
|---|---|
| **Mobile / Web Frontend** | Flutter, Dart, Riverpod, GoRouter, Material 3, Dio, `fl_chart`, `intl`, `url_launcher`, `image_picker` |
| **Backend REST API** | Python 3.12, FastAPI, Pydantic v2, SQLAlchemy 2.0, Alembic, Uvicorn |
| **Database** | SQLite for local development (zero setup cost), PostgreSQL compatible schema for cloud production |
| **AI / OCR Pipeline** | Google Gemini Vision (1.5 Flash / Pro) with structured JSON prompting, fallback offline mock mode |
| **Security & Auth** | JWT sessions, Passlib/Bcrypt hashing, shop-isolated queries, sanitized file uploads |
| **Communication** | WhatsApp Deep Links (`https://wa.me/?text=...`) without expensive SMS/Twilio gateways |
| **Dataset & ML** | Synthetic handwritten ledger generator, character/field accuracy, Precision/Recall/F1 evaluation suite |

---

## 3. Core Database Models

- **User**: Authentication, email, password hash, role (`SHOPKEEPER`, `ADMIN`).
- **Shop**: Shop profile, business name, owner name, phone, address, optional GSTIN.
- **Customer**: Customer profile, current net balance (+ credit / - payment), credit limit, address, notes.
- **Transaction**: Ledger records (`CREDIT`, `PAYMENT`, `ADJUSTMENT`), timestamp, customer ID, shop ID, source (`MANUAL`, `AI_SCAN`), reference scan entry ID.
- **Scan**: Document photograph, upload timestamp, image paths (original + enhanced), status (`PROCESSING`, `NEEDS_REVIEW`, `CONFIRMED`, `FAILED`), raw response.
- **ScanEntry**: Extracted row from photograph, customer name, amount, date, transaction type, confidence breakdown (`customer_name`, `amount`, `date`, `overall`), review status (`PENDING`, `CONFIRMED`, `EDITED`, `REJECTED`), corrected values, confirmation timestamp.
- **AuditLog**: Complete traceability of who confirmed or edited what value, preserving original AI text vs final confirmed text.
- **Reminder**: WhatsApp reminder logs with generated text, recipient phone, and balance timestamp.

---

## 4. Confidence & Verification System

| Confidence Band | Range | UI Status Badge | Action Allowed |
|---|---|---|---|
| **High Confidence** | $\ge 95\%$ | Green (`High Confidence`) | Eligible for single-click "Confirm All High" or individual confirmation |
| **Needs Review** | $80\% - 94\%$ | Amber (`Needs Review`) | Visual highlight, shopkeeper should inspect before confirming |
| **Manual Verification** | $< 80\%$ | Red (`Manual Verification Required`) | Mandatory manual field review and confirmation |

*Rule: Financial data is NEVER silently accepted without user confirmation when uncertainty exists.*

---

## 5. 13-Phase Implementation Roadmap

1. **Phase 1: Project Foundation & Environment Setup** (Configs, `.gitignore`, `.env.example`, dependencies)
2. **Phase 2: Database Layer & Seed Engine** (SQLAlchemy models, Alembic, development seed data)
3. **Phase 3: Gemini Vision OCR Pipeline** (Prompt engineering, structured JSON parser, confidence scoring, offline mock)
4. **Phase 4: Smart Matching & Fraud Protection** (Levenshtein/Jaro-Winkler customer matching, duplicate transaction guard)
5. **Phase 5: FastAPI REST API** (Auth, shops, customers, transactions, scans, scan entries, dashboard, reminders, reports)
6. **Phase 6: Image Preprocessing Engine** (EXIF rotation, contrast enhancement, compression, thumbnail generation)
7. **Phase 7: Flutter Architecture & Theming** (Material 3 Indian Kirana theme, Riverpod state, GoRouter navigation)
8. **Phase 8: Mobile UI Screens** (Splash, Auth, Dashboard, Scanner, Review, Customer Management, Ledger, WhatsApp Reminders)
9. **Phase 9: Dataset Structure & Evaluation Suite** (Synthetic image generator, accuracy, precision, recall, F1 metrics)
10. **Phase 10: Automated Testing & Verification** (Pytest suite, API integration tests, Flutter widget tests)
11. **Phase 11: Security & Production Hardening** (Zero secret leaks, CORS, rate limiting, shop isolation)
12. **Phase 12: Comprehensive Documentation** (12 detailed Markdown manuals)
13. **Phase 13: Final Build Verification & Walkthrough**
