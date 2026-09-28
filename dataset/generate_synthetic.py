"""
Synthetic Khata Generator for KhataSetu
=======================================
Generates realistic simulated handwritten Indian kirana khata ledger pages
with ground-truth JSON annotations for training, validation, and evaluation.
"""

import os
import json
import random
import datetime
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SAMPLE_CUSTOMERS = [
    ("Ramesh Kumar", "9811223344"),
    ("Suresh Verma", "9822334455"),
    ("Anita Devi", "9833445566"),
    ("Mohan Lal", "9844556677"),
    ("Rajesh Sharma", "9855667788"),
    ("Vikram Singh", "9866778899"),
    ("Priya Patel", "9877889900"),
    ("Sunita Gupta", "9888990011"),
    ("Manoj Tiwari", "9899001122"),
    ("Deepak Joshi", "9812345678"),
    ("Gopal Ji", "9823456789"),
    ("Santosh Bhai", "9834567890"),
]

SAMPLE_ITEMS = [
    "5kg aata", "1L tel", "2kg cheeni", "haldi mirchi", "chai patti",
    "surf excel", "dettol sabun", "arhar dal", "besan", "namak",
    "desi ghee", "sarson tel", "chawal 10kg", "maggi packet", "biscuit"
]

PEN_COLORS = [
    (18, 28, 85),    # Deep ballpoint blue
    (30, 30, 35),    # Black ink
    (60, 60, 65),    # Pencil gray
    (140, 20, 20),   # Red ink
]

PAPER_TINTS = [
    (253, 250, 240), # Cream register paper
    (248, 245, 235), # Aged yellow paper
    (255, 255, 252), # Off-white ruled paper
]


def generate_khata_page(image_path: str, annotation_path: str, num_entries: int = 6):
    width, height = 900, 1200
    paper_color = random.choice(PAPER_TINTS)
    img = Image.new("RGB", (width, height), color=paper_color)
    draw = ImageDraw.Draw(img)

    # 1. Draw ledger ruled lines
    # Red left margin
    margin_x = 90
    draw.line([(margin_x, 0), (margin_x, height)], fill=(225, 140, 140), width=2)
    # Right column divider for amounts
    divider_x = 650
    draw.line([(divider_x, 0), (divider_x, height)], fill=(190, 210, 235), width=1)

    # Horizontal ruled lines
    row_height = 50
    header_y = 100
    for y in range(header_y, height - 80, row_height):
        draw.line([(30, y), (width - 30, y)], fill=(215, 230, 245), width=1)

    # Header text
    today = datetime.date.today()
    header_text = f"KHATA REGISTER — {today.strftime('%d-%m-%Y')}"
    draw.text((margin_x + 20, 40), header_text, fill=(70, 70, 95))
    draw.text((margin_x + 20, 75), "NAME & PARTICULARS", fill=(120, 120, 140))
    draw.text((divider_x + 20, 75), "AMOUNT (Rs.)", fill=(120, 120, 140))

    entries_data = []
    selected_customers = random.sample(SAMPLE_CUSTOMERS, min(num_entries, len(SAMPLE_CUSTOMERS)))

    for i, (cust_name, phone) in enumerate(selected_customers):
        y_pos = header_y + (i * row_height) + 12
        pen_color = random.choice(PEN_COLORS)
        is_payment = random.random() < 0.25
        tx_type = "payment" if is_payment else "credit"

        if is_payment:
            amount = float(random.choice([200, 500, 1000, 1500, 2000]))
            description = f"{cust_name} — Jama / Rokad"
        else:
            amount = float(random.randint(40, 1450))
            items_desc = ", ".join(random.sample(SAMPLE_ITEMS, random.randint(1, 2)))
            description = f"{cust_name} — {items_desc}"

        # Write text with slight hand jitter
        jitter_x = random.randint(-2, 2)
        jitter_y = random.randint(-2, 2)
        draw.text((margin_x + 15 + jitter_x, y_pos + jitter_y), description, fill=pen_color)

        amt_str = f"{amount:.2f}"
        draw.text((divider_x + 25 + jitter_x, y_pos + jitter_y), amt_str, fill=pen_color)

        # Ground truth record
        entries_data.append({
            "entry_id": i + 1,
            "bounding_box": [margin_x, y_pos - 5, width - 40, y_pos + 35],
            "customer_name": cust_name,
            "amount": amount,
            "date": today.isoformat(),
            "transaction_type": tx_type,
            "raw_transcription": f"{description} {amt_str}",
            "is_crossed_out": False,
            "confidence_benchmark": 1.0,
        })

    # Slight realistic blur & grain simulation
    img = img.filter(ImageFilter.GaussianBlur(radius=0.4))

    os.makedirs(os.path.dirname(image_path), exist_ok=True)
    os.makedirs(os.path.dirname(annotation_path), exist_ok=True)

    img.save(image_path, "JPEG", quality=88)

    annotation = {
        "image_filename": os.path.basename(image_path),
        "image_dimensions": {"width": width, "height": height},
        "metadata": {
            "generated_at": datetime.datetime.utcnow().isoformat(),
            "is_synthetic": True,
            "total_entries": len(entries_data),
        },
        "entries": entries_data,
    }

    with open(annotation_path, "w", encoding="utf-8") as f:
        json.dump(annotation, f, indent=2, ensure_ascii=False)


def generate_synthetic_dataset(base_dir: str = "dataset"):
    splits = {"train": 5, "val": 2, "test": 3}
    total_generated = 0

    print("------------------------------------------------------------")
    print(f" GENERATING SYNTHETIC KHATA DATASET IN '{base_dir}/'")
    print("------------------------------------------------------------")

    for split, count in splits.items():
        img_dir = os.path.join(base_dir, "images", split)
        ann_dir = os.path.join(base_dir, "annotations", split)

        for idx in range(1, count + 1):
            img_name = f"khata_{split}_{idx:03d}.jpg"
            ann_name = f"khata_{split}_{idx:03d}.json"
            img_path = os.path.join(img_dir, img_name)
            ann_path = os.path.join(ann_dir, ann_name)

            generate_khata_page(img_path, ann_path, num_entries=random.randint(4, 7))
            total_generated += 1

    print(f" SUCCESS: Generated {total_generated} synthetic khata documents with ground-truth labels:")
    print(f" - Train: {splits['train']} images + annotations")
    print(f" - Val:   {splits['val']} images + annotations")
    print(f" - Test:  {splits['test']} images + annotations")
    print("------------------------------------------------------------")


if __name__ == "__main__":
    generate_synthetic_dataset()
