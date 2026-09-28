import pytest


def test_create_customer(client, auth_headers):
    payload = {
        "name": "Ramesh Kumar",
        "phone": "9811223344",
        "address": "House 12, Gali 4",
        "notes": "Regular dairy buyer",
    }
    response = client.post("/api/v1/customers/", json=payload, headers=auth_headers)
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Ramesh Kumar"
    assert data["credit_balance"] == 0.0
    assert data["total_credit"] == 0.0
    assert data["total_payment"] == 0.0


def test_create_duplicate_customer_rejected(client, auth_headers):
    payload = {"name": "Suresh Verma", "phone": "9822334455"}
    resp1 = client.post("/api/v1/customers/", json=payload, headers=auth_headers)
    assert resp1.status_code == 201

    # Attempt same customer again
    resp2 = client.post("/api/v1/customers/", json=payload, headers=auth_headers)
    assert resp2.status_code == 409


def test_list_and_search_customers(client, auth_headers):
    client.post("/api/v1/customers/", json={"name": "Anita Devi", "phone": "9833445566"}, headers=auth_headers)
    client.post("/api/v1/customers/", json={"name": "Mohan Lal", "phone": "9844556677"}, headers=auth_headers)

    # Search by name
    res = client.get("/api/v1/customers/?search=Anita", headers=auth_headers)
    assert res.status_code == 200
    customers = res.json()
    assert any(c["name"] == "Anita Devi" for c in customers)
    assert not any(c["name"] == "Mohan Lal" for c in customers)
