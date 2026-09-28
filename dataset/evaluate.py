"""
KhataSetu OCR Dataset Evaluator
================================
Evaluates extraction accuracy against ground-truth annotations across:
- Customer Name Exact Match & Levenshtein Accuracy
- Monetary Amount Exact Match & Percentage Error
- Transaction Type Accuracy
- Date Accuracy
- Overall Entry-level Precision, Recall, and F1 Score
- Confidence Calibration Error (Expected vs Observed accuracy)
"""

import os
import sys
import json
import glob
from typing import Dict, List, Any

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

from backend.services.ocr_service import OCRService
from backend.services.matching_service import MatchingService


def evaluate_split(split_name: str = "test", base_dir: str = "dataset") -> Dict[str, Any]:
    images_dir = os.path.join(base_dir, "images", split_name)
    annotations_dir = os.path.join(base_dir, "annotations", split_name)

    ann_files = glob.glob(os.path.join(annotations_dir, "*.json"))
    if not ann_files:
        print(f"No ground-truth annotations found in {annotations_dir}. Please run generate_synthetic.py first.")
        return {}

    total_gt_entries = 0
    total_pred_entries = 0
    correct_entries = 0

    name_matches = 0
    amount_matches = 0
    type_matches = 0
    date_matches = 0

    high_conf_total = 0
    high_conf_correct = 0

    print(f"Evaluating {len(ann_files)} documents from '{split_name}' split...")

    for ann_file in ann_files:
        with open(ann_file, "r", encoding="utf-8") as f:
            gt_data = json.load(f)

        img_filename = gt_data["image_filename"]
        img_path = os.path.join(images_dir, img_filename)

        gt_entries = gt_data.get("entries", [])
        total_gt_entries += len(gt_entries)

        # Run OCR extraction
        extraction_res = OCRService.extract_from_image(img_path)
        pred_entries = extraction_res.entries
        total_pred_entries += len(pred_entries)

        # Compare predicted entries with ground truth using greedy fuzzy matching
        matched_gt_indices = set()

        for pred in pred_entries:
            if not pred.customer_name or not pred.amount:
                continue

            best_match_idx = -1
            best_sim = 0.0

            for idx, gt in enumerate(gt_entries):
                if idx in matched_gt_indices:
                    continue
                sim = MatchingService.calculate_name_similarity(pred.customer_name, gt["customer_name"])
                if sim > best_sim:
                    best_sim = sim
                    best_match_idx = idx

            if best_match_idx >= 0 and best_sim >= 0.70:
                matched_gt_indices.add(best_match_idx)
                gt = gt_entries[best_match_idx]

                # 1. Customer Name Evaluation
                if best_sim >= 0.90:
                    name_matches += 1

                # 2. Amount Evaluation (Exact or within ₹1 rounding)
                if abs(float(pred.amount) - float(gt["amount"])) <= 1.0:
                    amount_matches += 1

                # 3. Transaction Type Evaluation
                if (pred.transaction_type or "").lower() == (gt["transaction_type"] or "").lower():
                    type_matches += 1

                # 4. Date Evaluation
                if pred.date and gt.get("date") and pred.date[:10] == gt["date"][:10]:
                    date_matches += 1

                # 5. Full Entry Exact Match
                if best_sim >= 0.90 and abs(float(pred.amount) - float(gt["amount"])) <= 1.0:
                    correct_entries += 1

                # Confidence Calibration
                if pred.confidence.overall >= 0.95:
                    high_conf_total += 1
                    if best_sim >= 0.90 and abs(float(pred.amount) - float(gt["amount"])) <= 1.0:
                        high_conf_correct += 1

    # Compute Metrics
    precision = correct_entries / max(1, total_pred_entries)
    recall = correct_entries / max(1, total_gt_entries)
    f1 = (2 * precision * recall) / max(1e-6, precision + recall)

    name_acc = name_matches / max(1, total_gt_entries)
    amount_acc = amount_matches / max(1, total_gt_entries)
    type_acc = type_matches / max(1, total_gt_entries)
    date_acc = date_matches / max(1, total_gt_entries)

    high_conf_accuracy = high_conf_correct / max(1, high_conf_total)

    results = {
        "split": split_name,
        "total_documents": len(ann_files),
        "ground_truth_entries": total_gt_entries,
        "predicted_entries": total_pred_entries,
        "entry_exact_matches": correct_entries,
        "precision": round(precision, 4),
        "recall": round(recall, 4),
        "f1_score": round(f1, 4),
        "field_accuracies": {
            "customer_name_accuracy": round(name_acc, 4),
            "amount_accuracy": round(amount_acc, 4),
            "transaction_type_accuracy": round(type_acc, 4),
            "date_accuracy": round(date_acc, 4),
        },
        "confidence_calibration": {
            "high_confidence_samples": high_conf_total,
            "high_confidence_accuracy": round(high_conf_accuracy, 4),
            "calibrated": high_conf_accuracy >= 0.90,
        }
    }

    print("============================================================")
    print(f" KHATASETU OCR EVALUATION RESULTS [{split_name.upper()} SPLIT]")
    print("============================================================")
    print(f" Documents Processed:       {results['total_documents']}")
    print(f" Ground Truth Entries:      {results['ground_truth_entries']}")
    print(f" Predicted Entries:         {results['predicted_entries']}")
    print("------------------------------------------------------------")
    print(f" Precision:                 {results['precision'] * 100:.2f}%")
    print(f" Recall:                    {results['recall'] * 100:.2f}%")
    print(f" F1 Score:                  {results['f1_score'] * 100:.2f}%")
    print("------------------------------------------------------------")
    print(" Field-Level Accuracies:")
    print(f"   * Customer Name:         {results['field_accuracies']['customer_name_accuracy'] * 100:.2f}%")
    print(f"   * Amount:                {results['field_accuracies']['amount_accuracy'] * 100:.2f}%")
    print(f"   * Transaction Type:      {results['field_accuracies']['transaction_type_accuracy'] * 100:.2f}%")
    print(f"   * Date:                  {results['field_accuracies']['date_accuracy'] * 100:.2f}%")
    print("------------------------------------------------------------")
    print(" Confidence Calibration Analysis:")
    print(f"   * Samples >= 0.95 Conf:  {results['confidence_calibration']['high_confidence_samples']}")
    print(f"   * Observed Accuracy:     {results['confidence_calibration']['high_confidence_accuracy'] * 100:.2f}%")
    print(f"   * Calibration Valid:     {results['confidence_calibration']['calibrated']}")
    print("============================================================")

    return results


if __name__ == "__main__":
    evaluate_split("test")
