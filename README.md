# KhataSetu — From Paper Khata to Smart Digital Khata

KhataSetu is a modern ledger management application built specifically for Indian Kirana shop owners. It digitizes handwritten paper khatas using AI Vision OCR (Gemini 1.5), manages customer balances securely, and sends deep-link reminders via WhatsApp.

## 🏗 Architecture & Tech Stack
- **Frontend**: Flutter (Mobile: Android, Web)
- **Backend**: FastAPI (Python 3.12+)
- **Database**: PostgreSQL (Production) / SQLite (Local Development)
- **AI/OCR**: Google Gemini 1.5 Flash Vision (via GenAI SDK)
- **Image Storage**: Cloud Object Storage (e.g., S3/GCS) in Production, Local `./uploads` in Development.

## ✨ Features & Supported Platforms
- **AI Scan & OCR**: Upload photos of handwritten ledgers to auto-extract customer names, amounts, and dates.
- **Fuzzy Matching**: Matches misspelled or differently written names to the correct customer record.
- **Ledger Management**: Track Udhar (credit) and Jama (payments).
- **Supported Platforms**: 
  - Android (APK)
  - Web (Flutter Web)

## 📸 Screenshots
*(Please add screenshots here)*
- [Placeholder: Dashboard Screenshot]
- [Placeholder: AI Scan Result Screenshot]
- [Placeholder: Customer Details Screenshot]

## 🛠 Local Development Setup

### Backend (FastAPI)
1. Navigate to the `backend` directory.
2. Create and activate a Python virtual environment.
3. Install dependencies: `pip install -r requirements.txt`
4. Set up the `.env` file (copy from `.env.example`).
5. Initialize the database using Alembic migrations:
   ```bash
   alembic upgrade head
   ```
6. Run the server:
   ```bash
   uvicorn main:app --reload
   ```

### Frontend (Flutter)
1. Navigate to the `frontend` directory.
2. Install dependencies: `flutter pub get`
3. Run the app: 
   ```bash
   flutter run -d chrome
   ```

## 🔐 Required Environment Variables
Create a `.env` file in the `backend` directory with the following variables:
- `APP_ENV`: Environment (e.g., `development` or `production`).
- `DATABASE_URL`: Connection string (e.g., `postgresql://user:pass@host/db`).
- `JWT_SECRET`: A secure, random string (Required for production).
- `CORS_ORIGINS`: Comma-separated list of allowed origins.
- `GEMINI_API_KEY`: API Key for Google Gemini Vision.
- `UPLOAD_DIR`: Directory for storing images (local mode only).

*Note: Do not commit `.env` or any secrets to version control.*

## 🗄 Database Setup and Migration
We use **Alembic** for database migrations.
- To run migrations and update your database schema to the latest version:
  ```bash
  alembic upgrade head
  ```
- To create a new migration after modifying models in `models/`:
  ```bash
  alembic revision --autogenerate -m "Your message"
  ```

## 🚀 Production Deployment Guide
1. **Backend**: 
   - Deploy as a Docker container or directly on platforms like Render/Heroku.
   - Set the `DATABASE_URL` to your production PostgreSQL database.
   - Set `APP_ENV=production` and generate a strong `JWT_SECRET`.
   - Set `CORS_ORIGINS` to match your deployed frontend URL.
2. **Frontend**:
   - Build for web:
     ```bash
     flutter build web --release --dart-define=API_URL=https://khatasetu.onrender.com/api/v1
     ```
   - Deploy the generated `build/web` folder to any static hosting provider (e.g., Render, Firebase Hosting, Vercel).
3. **Storage**: Configure a cloud storage bucket (S3, GCS, Firebase) for handling image uploads. Local file storage is ephemeral on platforms like Render and will lead to data loss.

## 📖 API Documentation
Once the backend is running, visit the interactive API documentation at:
- Swagger UI: `http://localhost:8000/docs` (or your production URL `https://khatasetu.onrender.com/docs`)

## 🛡 Security & Privacy
- **JWT Authentication**: User sessions are securely managed. The secret key must be rotated if compromised.
- **Data Isolation**: All endpoints verify the logged-in user and only return data belonging to their shop.
- **CORS**: Enforced explicitly. Credentials (cookies/auth headers) are only accepted from whitelisted origins.

## ⚠️ Current Limitations
- **Image Storage**: The current codebase uses local storage for uploads (`/uploads`). On ephemeral platforms like Render, images will be lost on server restart. A cloud storage solution (like AWS S3) must be integrated for production use.
- **Free-Tier Limits**: If using free hosting, the backend may sleep after inactivity, causing delays on the first request.

## 🧪 Test Commands
- **Backend Tests**: Run `pytest` inside the `backend` directory.
- **Frontend Tests**: Run `flutter test` inside the `frontend` directory.
