import io
import pytest
from PIL import Image


def create_dummy_image_bytes():
    img = Image.new("RGB", (300, 300), color=(250, 250, 240))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_scan_upload_and_extraction(client, auth_headers):
    img_bytes = create_dummy_image_bytes()
    files = {"file": ("test_page.jpg", img_bytes, "image/jpeg")}

    resp = client.post("/api/v1/scans/upload", files=files, headers=auth_headers)
    assert resp.status_code == 201
    data = resp.json()

    assert data["total_entries"] > 0
    assert "entries" in data
    assert len(data["entries"]) == data["total_entries"]

    # Check confidence properties on first entry
    entry = data["entries"][0]
    assert "confidence_overall" in entry
    assert "confidence_band" in entry
    assert entry["confidence_band"] in ("HIGH", "NEEDS_REVIEW", "MANUAL_VERIFICATION")
    assert entry["status"] == "PENDING"


def test_scan_entry_human_edit_and_audit_trail(client, auth_headers):
    # Upload scan first
    img_bytes = create_dummy_image_bytes()
    files = {"file": ("test_page2.jpg", img_bytes, "image/jpeg")}
    scan_data = client.post("/api/v1/scans/upload", files=files, headers=auth_headers).json()

    entry = scan_data["entries"][0]
    entry_id = entry["id"]

    # Human edits name and amount: e.g. "Ramesh" corrected to "Rameshwar", "450" to "460"
    edit_payload = {
        "customer_name": "Rameshwar Verma",
        "amount": 460.0,
        "transaction_type": "CREDIT",
    }
    edit_resp = client.post(f"/api/v1/scans/entries/{entry_id}/edit-and-confirm", json=edit_payload, headers=auth_headers)
    assert edit_resp.status_code == 200
    confirmed = edit_resp.json()

    # Verify state
    assert confirmed["status"] == "EDITED_CONFIRMED"
    assert confirmed["corrected_customer_name"] == "Rameshwar Verma"
    assert confirmed["corrected_amount"] == 460.0

    # Verify ledger transaction was generated with corrected amount
    txs = client.get("/api/v1/transactions/", headers=auth_headers).json()
    assert any(t["amount"] == 460.0 and t["scan_entry_id"] == entry_id for t in txs)


def test_batch_confirm_high_confidence_rule(client, auth_headers):
    img_bytes = create_dummy_image_bytes()
    files = {"file": ("test_page3.jpg", img_bytes, "image/jpeg")}
    scan_data = client.post("/api/v1/scans/upload", files=files, headers=auth_headers).json()
    scan_id = scan_data["id"]

    # Trigger batch confirm
    batch_resp = client.post("/api/v1/scans/batch-confirm-high", json={"scan_id": scan_id}, headers=auth_headers)
    assert batch_resp.status_code == 200

    # Fetch updated scan: high confidence entries must be CONFIRMED, medium/low must remain PENDING
    updated_scan = client.get(f"/api/v1/scans/{scan_id}", headers=auth_headers).json()
    for e in updated_scan["entries"]:
        if e["confidence_band"] == "HIGH":
            assert e["status"] == "CONFIRMED"
        else:
            assert e["status"] == "PENDING"
