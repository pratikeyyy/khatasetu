import pytest


def test_transaction_balance_calculation(client, auth_headers):
    # 1. Create Customer
    cust_res = client.post("/api/v1/customers/", json={"name": "Kishore Kumar", "phone": "9899112233"}, headers=auth_headers)
    cust_id = cust_res.json()["id"]

    # 2. Add Credit Transaction: ₹500
    tx1 = client.post(
        "/api/v1/transactions/",
        json={"customer_id": cust_id, "amount": 500.0, "transaction_type": "CREDIT", "notes": "Udhar rashan"},
        headers=auth_headers,
    )
    assert tx1.status_code == 201

    # Check Customer Balance -> Should be ₹500.00
    cust_check1 = client.get(f"/api/v1/customers/{cust_id}", headers=auth_headers).json()
    assert cust_check1["credit_balance"] == 500.0
    assert cust_check1["total_credit"] == 500.0
    assert cust_check1["total_payment"] == 0.0

    # 3. Add Payment Transaction: ₹200
    tx2 = client.post(
        "/api/v1/transactions/",
        json={"customer_id": cust_id, "amount": 200.0, "transaction_type": "PAYMENT", "notes": "Cash Jama"},
        headers=auth_headers,
    )
    assert tx2.status_code == 201

    # Check Customer Balance -> Outstanding should be ₹300.00 (500 - 200)
    cust_check2 = client.get(f"/api/v1/customers/{cust_id}", headers=auth_headers).json()
    assert cust_check2["credit_balance"] == 300.0
    assert cust_check2["total_credit"] == 500.0
    assert cust_check2["total_payment"] == 200.0


def test_duplicate_transaction_protection(client, auth_headers):
    cust_res = client.post("/api/v1/customers/", json={"name": "Deepak Bhai", "phone": "9877001122"}, headers=auth_headers)
    cust_id = cust_res.json()["id"]

    # First entry
    tx1 = client.post(
        "/api/v1/transactions/",
        json={"customer_id": cust_id, "amount": 750.0, "transaction_type": "CREDIT", "notes": "Aata bag"},
        headers=auth_headers,
    )
    assert tx1.status_code == 201

    # Attempt identical entry without force flag -> Should be flagged 409 Conflict
    tx2 = client.post(
        "/api/v1/transactions/",
        json={"customer_id": cust_id, "amount": 750.0, "transaction_type": "CREDIT", "notes": "Aata bag"},
        headers=auth_headers,
    )
    assert tx2.status_code == 409

    # Retry with force=true -> Should succeed (Shopkeeper explicitly confirms Keep Both)
    tx3 = client.post(
        "/api/v1/transactions/?force=true",
        json={"customer_id": cust_id, "amount": 750.0, "transaction_type": "CREDIT", "notes": "Aata bag"},
        headers=auth_headers,
    )
    assert tx3.status_code == 201
