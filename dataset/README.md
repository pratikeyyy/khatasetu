# KhataSetu OCR Dataset Specification & Annotation Guidelines

## Overview
This dataset specification defines the standards for collecting, annotating, evaluating, and training vision/OCR models on Indian handwritten paper khata (kirana ledger) documents.

---

## 1. Directory Structure

```
dataset/
├── images/
│   ├── train/          # Training split images (.jpg, .png)
│   ├── val/            # Validation split images (.jpg, .png)
│   └── test/           # Held-out testing split images (.jpg, .png)
├── annotations/
│   ├── train/          # Ground truth JSON files for train split
│   ├── val/            # Ground truth JSON files for val split
│   └── test/           # Ground truth JSON files for test split
├── generate_synthetic.py  # Synthetic khata image & label generator
├── evaluate.py            # Precision, Recall, F1 & field accuracy evaluator
└── README.md              # This specification document
```

---

## 2. Document Varieties & Edge Cases
Khata registers in Indian Kirana shops exhibit unique challenges that models must handle:

1. **Bilingual & Script Variations**:
   - Devanagari script: `रमेश कुमार`, `उधार`, `जमा`, `रोकड़`
   - Latin script: `Ramesh Kumar`, `Udhar`, `Jama`, `Cash`
   - Hinglish mix: `Ramesh 5kg aata`, `Suresh bhai 1200 jama`
2. **Numerals & Currency Symbols**:
   - Arabic numerals: `1200`, `450.50`, `₹500`, `Rs. 500`
   - Devanagari numerals: `१२००`, `४५०`
   - Common Kirana notations: `/-`, `=/`, `.-` (e.g. `500/-`)
3. **Paper & Ink Conditions**:
   - Ruled blue/red ledger registers (*Lal Bahi Khata*)
   - Plain recycled paper, yellowed/aged pages
   - Blue ballpoint, black gel, red ink, pencil
   - Faded ink, water stains, fold creases, shadows from poor shop lighting
4. **Layout Patterns**:
   - Tabular two-column layout: Left (*Jama* / Payments) and Right (*Naam / Udhar* / Credit)
   - Sequential single-column register: Name followed by Amount and brief description
   - Crossed-out / struck-through entries (indicating paid or cancelled transactions)

---

## 3. Ground Truth Annotation Schema

Each image has a corresponding JSON file in `annotations/` matching `<image_basename>.json`:

```json
{
  "image_filename": "khata_001.jpg",
  "image_dimensions": {
    "width": 1200,
    "height": 1600
  },
  "metadata": {
    "paper_type": "ruled_red_bahi",
    "ink_color": "blue_ballpoint",
    "language": "hinglish",
    "lighting_condition": "moderate_ambient"
  },
  "entries": [
    {
      "entry_id": 1,
      "bounding_box": [120, 340, 980, 410],
      "customer_name": "Ramesh Kumar",
      "amount": 450.0,
      "date": "2026-09-19",
      "transaction_type": "credit",
      "raw_transcription": "Ramesh Kumar 450 udhar 5kg aata",
      "is_crossed_out": false,
      "confidence_benchmark": 1.0
    }
  ]
}
```

---

## 4. Evaluation Metrics

The evaluation script (`dataset/evaluate.py`) computes:
- **Field-Level Exact Match (EM)**: Customer Name, Amount, Date, Transaction Type
- **Character Error Rate (CER)** and **Word Error Rate (WER)** on customer names
- **Mean Absolute Percentage Error (MAPE)** on amounts
- **Precision, Recall, and F1 Score** on detected entries
- **Confidence Calibration Error (ECE)**: Verifying whether high-confidence scores ($\ge 0.95$) genuinely reflect $\ge 95\%$ accuracy.
