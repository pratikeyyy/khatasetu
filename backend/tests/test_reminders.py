import pytest
import urllib.parse
from backend.services.reminder_service import ReminderService


def test_clean_phone_number():
    # 10-digit standard Indian phone
    assert ReminderService.clean_phone_number("9876543210") == "919876543210"

    # Number with +91 and spaces/dashes
    assert ReminderService.clean_phone_number("+91 98765-43210") == "919876543210"

    # Number with leading zero
    assert ReminderService.clean_phone_number("09876543210") == "919876543210"

    # Already with 91
    assert ReminderService.clean_phone_number("919876543210") == "919876543210"


def test_whatsapp_deep_link_generation():
    link_info = ReminderService.generate_whatsapp_deep_link(
        phone="9876543210",
        customer_name="Ramesh",
        amount=500.0,
        shop_name="Radheshyam Store",
        language="hinglish",
    )

    url = link_info["whatsapp_url"]
    assert url.startswith("https://wa.me/919876543210?text=")
    # Extract query param and decode
    parsed = urllib.parse.urlparse(url)
    params = urllib.parse.parse_qs(parsed.query)
    decoded_text = params["text"][0]

    assert "Namaste Ramesh ji" in decoded_text
    assert "₹500.00" in decoded_text
    assert "Radheshyam Store" in decoded_text


def test_whatsapp_reminder_endpoint(client, auth_headers):
    # 1. Create Customer
    cust_res = client.post(
        "/api/v1/customers/",
        json={"name": "Suresh Ji", "phone": "9811223344"},
        headers=auth_headers,
    )
    cust_id = cust_res.json()["id"]

    # 2. Add Credit of ₹1200
    client.post(
        "/api/v1/transactions/",
        json={"customer_id": cust_id, "amount": 1200.0, "transaction_type": "CREDIT"},
        headers=auth_headers,
    )

    # 3. Generate Reminder
    rem_res = client.post(
        "/api/v1/reminders/whatsapp",
        json={"customer_id": cust_id, "language": "hinglish"},
        headers=auth_headers,
    )
    assert rem_res.status_code == 200
    data = rem_res.json()
    assert data["customer_name"] == "Suresh Ji"
    assert data["outstanding_amount"] == 1200.0
    assert "https://wa.me/919811223344" in data["whatsapp_url"]
