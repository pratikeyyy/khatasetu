"""
KhataSetu Development Database Seeder
====================================
WARNING: THIS SCRIPT GENERATES SYNTHETIC DEVELOPMENT DATA ONLY.
NEVER RUN IN PRODUCTION ENVIRONMENTS.
"""

import os
import sys
import datetime
from PIL import Image, ImageDraw, ImageFont

# Support Unicode symbols (₹) on Windows console
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# Add project root to sys.path
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

from backend.config import settings
from backend.database import Base, engine, SessionLocal
from backend.models.user import User
from backend.models.shop import Shop
from backend.models.customer import Customer
from backend.models.transaction import Transaction
from backend.models.scan import Scan, ScanEntry
from backend.models.audit import AuditLog
from backend.services.auth_service import get_password_hash
from backend.services.matching_service import MatchingService


def create_sample_khata_image(output_path: str):
    """Creates a synthetic handwritten-style khata page image for development scans."""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img = Image.new("RGB", (800, 1000), color=(253, 250, 242))  # Cream register paper
    draw = ImageDraw.Draw(img)

    # Draw faint ledger lines (blue and red)
    draw.line([(80, 0), (80, 1000)], fill=(220, 150, 150), width=2)   # Red margin line
    draw.line([(550, 0), (550, 1000)], fill=(180, 200, 230), width=1) # Amount divider

    for y in range(80, 950, 45):
        draw.line([(20, y), (780, y)], fill=(210, 225, 245), width=1)

    # Write sample register header and entries
    draw.text((100, 30), "SHREE GANESHAY NAMAH - KHATA REGISTER 2026", fill=(60, 60, 90))
    draw.text((100, 100), "Ramesh Kumar - 5kg aata, tel", fill=(20, 20, 80))
    draw.text((600, 100), "450.00", fill=(20, 20, 80))

    draw.text((100, 145), "Suresh Verma - Jama rokad (cash)", fill=(20, 20, 80))
    draw.text((600, 145), "1200.00", fill=(20, 20, 80))

    draw.text((100, 190), "Anita Devi - tel, masala", fill=(20, 20, 80))
    draw.text((600, 190), "320.00", fill=(20, 20, 80))

    draw.text((100, 235), "Mohan Lal - chai patti", fill=(20, 20, 80))
    draw.text((600, 235), "85.00", fill=(20, 20, 80))

    draw.text((100, 280), "Pankaj - dhaniya, mirchi", fill=(20, 20, 80))
    draw.text((600, 280), "740.00", fill=(20, 20, 80))

    img.save(output_path, "JPEG", quality=90)


def seed_database():
    print("------------------------------------------------------------")
    print(" KHATASETU — SEEDING DEVELOPMENT DATABASE")
    print("------------------------------------------------------------")

    # Recreate tables
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    try:
        # Check if shopkeeper user exists
        demo_email = "shopkeeper@khatasetu.com"
        existing_user = db.query(User).filter(User.email == demo_email).first()
        if existing_user:
            print(f"User {demo_email} already exists. Cleaning existing test records...")
            db.query(AuditLog).delete()
            db.query(Transaction).delete()
            db.query(ScanEntry).delete()
            db.query(Scan).delete()
            db.query(Customer).delete()
            db.query(Shop).delete()
            db.query(User).delete()
            db.commit()

        # 1. Create Demo User
        user = User(
            email=demo_email,
            password_hash=get_password_hash("password123"),
            full_name="Radheshyam Sharma",
            phone="9876543210",
            is_active=True,
            is_verified=True,
            role="SHOPKEEPER",
        )
        db.add(user)
        db.flush()

        # 2. Create Demo Kirana Shop
        shop = Shop(
            owner_id=user.id,
            name="Radheshyam Kirana & General Store",
            owner_name="Radheshyam Sharma",
            phone="9876543210",
            address="Shop #14, Main Market, Chandni Chowk, Delhi - 110006",
            gstin="07AAAAA0000A1Z5",
            currency="INR",
            currency_symbol="₹",
        )
        db.add(shop)
        db.flush()

        # 3. Create 5 Realistic Customers
        customers_data = [
            {
                "name": "Ramesh Kumar",
                "phone": "9811223344",
                "address": "Gali No. 3, Chandni Chowk",
                "notes": "Regular customer. Pays on 1st of every month.",
            },
            {
                "name": "Suresh Verma",
                "phone": "9822334455",
                "address": "House #45, Near Shiv Mandir",
                "notes": "Contractor. Takes bulk dairy and grains.",
            },
            {
                "name": "Anita Devi",
                "phone": "9833445566",
                "address": "Apartment 2B, Shanti Enclave",
                "notes": "Prefers WhatsApp reminders in Hindi.",
            },
            {
                "name": "Mohan Lal",
                "phone": "9844556677",
                "address": "Shop #8, Vegetable Market",
                "notes": "Small balance usually settled weekly.",
            },
            {
                "name": "Rajesh Sharma",
                "phone": "9855667788",
                "address": "Block C-12, Model Town",
                "notes": "Friend of owner. Timely UPI settlements.",
            },
        ]

        created_customers = []
        for c in customers_data:
            cust = Customer(
                shop_id=shop.id,
                name=c["name"],
                normalized_name=MatchingService.normalize_name(c["name"]),
                phone=c["phone"],
                address=c["address"],
                notes=c["notes"],
                credit_balance=0.0,
                total_credit=0.0,
                total_payment=0.0,
            )
            db.add(cust)
            created_customers.append(cust)

        db.flush()

        # 4. Create 15-20 Transactions across different dates
        now = datetime.datetime.utcnow()
        tx_specs = [
            (created_customers[0], 1200.0, "CREDIT", now - datetime.timedelta(days=12), "MANUAL", "Monthly ration"),
            (created_customers[0], 500.0, "PAYMENT", now - datetime.timedelta(days=10), "MANUAL", "Cash payment received"),
            (created_customers[0], 850.0, "CREDIT", now - datetime.timedelta(days=5), "MANUAL", "Oil and pulses"),
            (created_customers[0], 350.0, "CREDIT", now - datetime.timedelta(days=1), "AI_SCAN", "From register scan #1"),

            (created_customers[1], 3500.0, "CREDIT", now - datetime.timedelta(days=14), "MANUAL", "Bulk wheat bags (50kg)"),
            (created_customers[1], 2000.0, "PAYMENT", now - datetime.timedelta(days=7), "MANUAL", "UPI received"),
            (created_customers[1], 1500.0, "CREDIT", now - datetime.timedelta(days=2), "MANUAL", "Sugar and spices"),

            (created_customers[2], 950.0, "CREDIT", now - datetime.timedelta(days=8), "MANUAL", "Ghee and rice"),
            (created_customers[2], 950.0, "PAYMENT", now - datetime.timedelta(days=4), "MANUAL", "Full settlement cash"),
            (created_customers[2], 640.0, "CREDIT", now - datetime.timedelta(days=1), "MANUAL", "Daily groceries"),

            (created_customers[3], 420.0, "CREDIT", now - datetime.timedelta(days=6), "MANUAL", "Tea and snacks"),
            (created_customers[3], 200.0, "PAYMENT", now - datetime.timedelta(days=3), "MANUAL", "Partial cash"),
            (created_customers[3], 150.0, "CREDIT", now - datetime.timedelta(hours=5), "MANUAL", "Soap and detergent"),

            (created_customers[4], 1800.0, "CREDIT", now - datetime.timedelta(days=9), "MANUAL", "Festival shopping items"),
            (created_customers[4], 1800.0, "PAYMENT", now - datetime.timedelta(days=2), "MANUAL", "GPay transfer"),
        ]

        for cust, amt, t_type, t_date, src, notes in tx_specs:
            tx = Transaction(
                shop_id=shop.id,
                customer_id=cust.id,
                amount=amt,
                transaction_type=t_type,
                date=t_date,
                source=src,
                notes=notes,
            )
            db.add(tx)

        db.flush()

        # Recalculate customer balances
        for cust in created_customers:
            cust.recalculate_balance()

        # 5. Create a Sample Scanned Document with ScanEntries & Audit Trail
        sample_img_path = os.path.join(settings.UPLOAD_DIR, "demo_paper_khata_page.jpg")
        sample_proc_path = os.path.join(settings.UPLOAD_DIR, "demo_paper_khata_page_enhanced.jpg")
        sample_thumb_path = os.path.join(settings.UPLOAD_DIR, "demo_paper_khata_page_thumb.jpg")

        create_sample_khata_image(sample_img_path)
        create_sample_khata_image(sample_proc_path)
        create_sample_khata_image(sample_thumb_path)

        scan = Scan(
            shop_id=shop.id,
            original_image_path=sample_img_path,
            processed_image_path=sample_proc_path,
            thumbnail_path=sample_thumb_path,
            status="REVIEW_NEEDED",
            model_name="gemini-1.5-flash",
            total_entries=5,
            confirmed_entries=2,
            high_confidence_entries=2,
            processing_time_ms=1420,
        )
        db.add(scan)
        db.flush()

        # Entries for the scan:
        # Entry 1: High confidence, already confirmed
        e1 = ScanEntry(
            scan_id=scan.id,
            matched_customer_id=created_customers[0].id,
            extracted_customer_name="Ramesh Kumar",
            extracted_amount=450.0,
            extracted_date=now - datetime.timedelta(days=1),
            extracted_type="CREDIT",
            raw_text="Ramesh Kumar 450 udhar 5kg aata",
            confidence_customer_name=0.98,
            confidence_amount=0.99,
            confidence_date=0.95,
            confidence_type=0.96,
            confidence_overall=0.97,
            confidence_band="HIGH",
            is_date_inferred=False,
            status="CONFIRMED",
            confirmed_by_user_id=user.id,
            confirmed_at=now - datetime.timedelta(hours=2),
        )
        db.add(e1)

        # Entry 2: Confirmed with human correction (audit trail demo)
        e2 = ScanEntry(
            scan_id=scan.id,
            matched_customer_id=created_customers[1].id,
            extracted_customer_name="Suresh V",
            extracted_amount=1200.0,
            extracted_date=now - datetime.timedelta(days=1),
            extracted_type="PAYMENT",
            raw_text="Suresh V Jama 1200",
            confidence_customer_name=0.88,
            confidence_amount=0.98,
            confidence_date=0.92,
            confidence_type=0.95,
            confidence_overall=0.91,
            confidence_band="NEEDS_REVIEW",
            is_date_inferred=False,
            status="EDITED_CONFIRMED",
            corrected_customer_name="Suresh Verma",
            corrected_amount=1200.0,
            corrected_type="PAYMENT",
            confirmed_by_user_id=user.id,
            confirmed_at=now - datetime.timedelta(hours=1),
        )
        db.add(e2)

        # Entry 3: Pending review (Needs Review, 89% confidence)
        e3 = ScanEntry(
            scan_id=scan.id,
            matched_customer_id=created_customers[2].id,
            extracted_customer_name="Anita Devi",
            extracted_amount=320.0,
            extracted_date=now,
            extracted_type="CREDIT",
            raw_text="Anita D 320 tel masala",
            confidence_customer_name=0.88,
            confidence_amount=0.91,
            confidence_date=0.85,
            confidence_type=0.90,
            confidence_overall=0.89,
            confidence_band="NEEDS_REVIEW",
            is_date_inferred=False,
            status="PENDING",
        )
        db.add(e3)

        # Entry 4: Pending review (Missing date, inferred)
        e4 = ScanEntry(
            scan_id=scan.id,
            matched_customer_id=created_customers[3].id,
            extracted_customer_name="Mohan Lal",
            extracted_amount=85.0,
            extracted_date=now,
            extracted_type="CREDIT",
            raw_text="Mohan Lal 85 chai patti",
            confidence_customer_name=0.92,
            confidence_amount=0.95,
            confidence_date=0.00,
            confidence_type=0.90,
            confidence_overall=0.82,
            confidence_band="NEEDS_REVIEW",
            is_date_inferred=True,
            status="PENDING",
        )
        db.add(e4)

        # Entry 5: Manual verification required (< 80% confidence)
        e5 = ScanEntry(
            scan_id=scan.id,
            extracted_customer_name="Pankaj",
            extracted_amount=740.0,
            extracted_date=now,
            extracted_type="CREDIT",
            raw_text="Pankaj ?40 dhaniya",
            confidence_customer_name=0.72,
            confidence_amount=0.68,
            confidence_date=0.00,
            confidence_type=0.75,
            confidence_overall=0.69,
            confidence_band="MANUAL_VERIFICATION",
            is_date_inferred=True,
            status="PENDING",
        )
        db.add(e5)

        # 6. Audit Trail entries demonstrating full provenance
        audit1 = AuditLog(
            actor_id=user.id,
            action="SCAN_CONFIRMED",
            entity_type="SCAN_ENTRY",
            entity_id=1,
            original_value='{"name": "Ramesh Kumar", "amount": 450.0, "confidence": 0.97}',
            new_value='{"status": "CONFIRMED", "confirmed_by": "Radheshyam Sharma"}',
            change_summary="Confirmed high confidence AI entry for Ramesh Kumar (₹450.00 CREDIT)",
        )
        audit2 = AuditLog(
            actor_id=user.id,
            action="SCAN_EDITED_CONFIRMED",
            entity_type="SCAN_ENTRY",
            entity_id=2,
            original_value='{"name": "Suresh V", "amount": 1200.0, "confidence": 0.91}',
            new_value='{"name": "Suresh Verma", "amount": 1200.0, "type": "PAYMENT"}',
            change_summary="Corrected customer name from 'Suresh V' to 'Suresh Verma' and confirmed ₹1200.00 PAYMENT",
        )
        db.add(audit1)
        db.add(audit2)

        db.commit()

        print(" SUCCESS: Database seeded successfully with:")
        print(f" - 1 Shopkeeper user: {demo_email} (password: password123)")
        print(f" - 1 Kirana Shop: {shop.name}")
        print(f" - {len(created_customers)} Customers with calculated balances:")
        for c in created_customers:
            print(f"   * {c.name}: Balance ₹{c.credit_balance:.2f} (Total Credit: ₹{c.total_credit:.2f}, Paid: ₹{c.total_payment:.2f})")
        print(f" - {len(tx_specs)} Ledger Transactions")
        print(f" - 1 Scanned Register Page with 5 Entries (2 confirmed, 2 review needed, 1 manual verification)")
        print(f" - 2 Audit Trail records preserving AI values vs human corrections")
        print("------------------------------------------------------------")

    except Exception as e:
        db.rollback()
        print(f" ERROR seeding database: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()
