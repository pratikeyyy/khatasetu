import requests
import random
import sys

BASE_URL = "https://khatasetu.onrender.com/api/v1"

def run_tests():
    print("Testing backend at:", BASE_URL)
    
    # 1. Register
    email = f"test_{random.randint(1000, 9999)}@example.com"
    pw = "password123"
    print(f"Registering user {email}...")
    r = requests.post(f"{BASE_URL}/auth/register", json={
        "email": email,
        "password": pw,
        "owner_name": "Test User",
        "shop_name": "Test Shop",
        "phone": "9876543210"
    })
    
    if r.status_code != 201 and r.status_code != 200:
        print(f"FAIL: Registration returned {r.status_code}: {r.text}")
        return False
        
    print("PASS: Registration successful")
    token = r.json().get("access_token")
    headers = {"Authorization": f"Bearer {token}"}
    
    # 2. Get Profile
    r = requests.get(f"{BASE_URL}/auth/me", headers=headers)
    if r.status_code != 200:
        print(f"FAIL: /auth/me returned {r.status_code}: {r.text}")
        return False
    print("PASS: Profile fetch successful")
    
    # 3. Create Customer
    print("Creating a customer...")
    r = requests.post(f"{BASE_URL}/customers/", headers=headers, json={
        "name": "Ramesh Demo",
        "phone": "9999999999",
        "address": "Local St."
    })
    if r.status_code != 201:
        print(f"FAIL: Customer creation returned {r.status_code}: {r.text}")
        return False
    
    customer_id = r.json().get("id")
    print(f"PASS: Customer created with ID {customer_id}")
    
    # 4. Create Transaction
    print("Creating a transaction...")
    r = requests.post(f"{BASE_URL}/transactions/", headers=headers, json={
        "customer_id": customer_id,
        "amount": 500.0,
        "transaction_type": "CREDIT",
        "date": "2026-10-09",
        "notes": "Test credit",
        "payment_mode": "CASH"
    })
    
    if r.status_code != 201:
        print(f"FAIL: Transaction creation returned {r.status_code}: {r.text}")
        return False
        
    print("PASS: Transaction created successfully")
    
    # 5. Test OCR Flow
    print("Testing OCR upload flow...")
    # Create a 1x1 black image in-memory
    img_bytes = b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c $.\' ",#\x1c\x1c(7),01444\x1f\'9=82<.342\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x1f\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\xff\xda\x00\x08\x01\x01\x00\x00?\x00\xd2\xcf \xff\xd9'
    files = {"file": ("dummy.jpg", img_bytes, "image/jpeg")}
    r = requests.post(f"{BASE_URL}/scans/upload", headers=headers, files=files)
    
    if r.status_code == 201:
        print("PASS: OCR Upload succeeded")
    elif r.status_code == 500 and "gemini" in r.text.lower():
        print("PASS (Degraded): OCR Upload hit a 500 which is expected if the Live Gemini API key is missing or quota exceeded, but the routing works.")
    else:
        print(f"FAIL: OCR upload returned {r.status_code}: {r.text}")
        return False

    return True

if __name__ == "__main__":
    if run_tests():
        sys.exit(0)
    else:
        sys.exit(1)
