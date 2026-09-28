import pytest


def test_register_success(client):
    payload = {
        "email": "sharma.store@example.com",
        "password": "mypassword123",
        "owner_name": "Rameshwar Sharma",
        "shop_name": "Sharmaji Kirana",
        "phone": "9876543210",
        "shop_address": "Sector 4, Rohini, Delhi",
        "gstin": "07AAAAA0000A1Z5",
    }
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert "access_token" in data
    assert data["owner_name"] == "Rameshwar Sharma"
    assert data["shop_name"] == "Sharmaji Kirana"


def test_register_invalid_gstin(client):
    payload = {
        "email": "invalid.gstin@example.com",
        "password": "mypassword123",
        "owner_name": "Test Owner",
        "shop_name": "Test Shop",
        "phone": "9876543210",
        "gstin": "INVALID123",
    }
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 422  # Validation error on GSTIN format


def test_login_success(client):
    # Register first
    email = "login.test@example.com"
    pwd = "testloginpassword"
    client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": pwd,
            "owner_name": "Login Tester",
            "shop_name": "Test Mart",
            "phone": "9123456789",
        },
    )

    # Login
    response = client.post("/api/v1/auth/login", json={"email": email, "password": pwd})
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data


def test_login_invalid_password(client):
    response = client.post(
        "/api/v1/auth/login",
        json={"email": "nonexistent@example.com", "password": "wrongpassword"},
    )
    assert response.status_code == 401
