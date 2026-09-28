# KhataSetu — REST API Documentation

Base URL: `http://localhost:8000/api/v1`

All requests except `/auth/register` and `/auth/login` require an `Authorization: Bearer <JWT_TOKEN>` header.

---

## 1. Authentication (`/auth`)

### `POST /auth/register`
Creates a user account and an associated shop record atomically.
- **Payload:**
  ```json
  {
    "email": "owner@kirana.com",
    "password": "strongpassword",
    "owner_name": "Ramesh Kumar",
    "shop_name": "Ramesh Kirana Stores",
    "phone": "9876543210",
    "shop_address": "Shop 4, Gandhi Chowk",
    "gstin": "22AAAAA0000A1Z5"
  }
  ```
- **Response:** `201 Created` with JWT access token and user/shop details.

### `POST /auth/login`
- **Payload:** `OAuth2PasswordRequestForm` (`username` = email, `password` = password).
- **Response:** `{"access_token": "...", "token_type": "bearer"}`.

### `GET /auth/me`
Returns details of the currently authenticated shopkeeper.

---

## 2. Customers (`/customers`)

### `GET /customers/`
Lists all customers belonging to the current shop with filtering and sorting.
- **Query Params:**
  - `search`: string filter on name or phone
  - `sort_by`: `name` (default), `balance_desc`, `balance_asc`, `recent`

### `POST /customers/`
Creates a customer. Returns 400 if exact duplicate name/phone exists.
- **Payload:**
  ```json
  {
    "name": "Raju Sharma",
    "phone": "9823012345",
    "address": "Ward 2"
  }
  ```

### `GET /customers/{id}`
Returns customer profile along with current balance and transaction totals.

---

## 3. Transactions (`/transactions`)

### `POST /transactions/`
Adds a ledger transaction (Udhar or Jama).
- **Query Params:**
  - `force`: boolean (defaults to `false`). If `false`, checks for potential duplicate entries within 24 hours.
- **Payload:**
  ```json
  {
    "customer_id": 1,
    "amount": 450.0,
    "transaction_type": "CREDIT",
    "date": "2026-09-19T10:00:00Z",
    "notes": "Mustard oil 2L"
  }
  ```

### `POST /transactions/check-duplicate`
Checks whether a duplicate transaction exists within a 24-hour window.

---

## 4. Scans & AI Vision Pipeline (`/scans`)

### `POST /scans/upload`
Uploads a photographed khata register page (`multipart/form-data`). Runs image enhancement, triggers Gemini Vision OCR, evaluates confidence, stores entries as `ScanEntry`, and returns the created scan object.

### `GET /scans/{id}`
Retrieves a scan and all its detected entries with confidence scores and status.

### `POST /scans/{id}/entries/{entry_id}/confirm`
Accepts an extracted entry as-is and atomically inserts it into the shop ledger.

### `PUT /scans/{id}/entries/{entry_id}`
Modifies values of an extracted entry (e.g., corrected amount or name), confirms it, updates the ledger, and records an audit log entry.

### `DELETE /scans/{id}/entries/{entry_id}`
Marks an entry as `REJECTED`.

### `POST /scans/{id}/batch-confirm-high`
Batch-confirms only entries in the `HIGH` confidence band ($\ge 0.95$). Entries needing review remain pending.

---

## 5. Reminders (`/reminders`)

### `POST /reminders/whatsapp`
Generates a direct `wa.me` deep link with encoded multilingual text (Hindi, Hinglish, or English) and logs the reminder event.

---

## 6. Dashboard (`/dashboard`)

### `GET /dashboard/summary?days=7`
Returns aggregate shopkeeper KPIs:
- `total_outstanding`
- `today_credit`
- `today_payment`
- `total_scans`
- `pending_reviews_count`
- `trend_chart`: Daily credit and payment time series for chart rendering.
