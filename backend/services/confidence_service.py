from typing import Tuple, Dict
from backend.config import settings


class ConfidenceService:
    @staticmethod
    def calculate_overall_confidence(
        name_conf: float,
        amount_conf: float,
        date_conf: float,
        type_conf: float = 0.90,
    ) -> float:
        """
        Calculates a calibrated overall extraction confidence score.
        Critical Rule: In financial bookkeeping, if either amount or customer name is uncertain,
        the overall score must penalize the uncertainty.
        """
        # Weights: Amount (0.40), Customer Name (0.35), Date (0.15), Type (0.10)
        weighted_score = (
            (amount_conf * 0.40)
            + (name_conf * 0.35)
            + (date_conf * 0.15)
            + (type_conf * 0.10)
        )

        # Safety ceiling: If amount or name confidence is below 0.80, overall cannot exceed 0.79
        if amount_conf < 0.80 or name_conf < 0.80:
            weighted_score = min(weighted_score, 0.79)

        return round(max(0.0, min(1.0, weighted_score)), 2)

    @staticmethod
    def classify_confidence_band(overall_confidence: float) -> str:
        """
        Classifies score into one of three strict operational bands:
        - HIGH: >= 0.95 (Eligible for auto-batch confirmation)
        - NEEDS_REVIEW: 0.80 to 0.94 (Highlighted for quick shopkeeper review)
        - MANUAL_VERIFICATION: < 0.80 (Mandatory manual field inspection)
        """
        if overall_confidence >= settings.CONFIDENCE_HIGH_THRESHOLD:
            return "HIGH"
        elif overall_confidence >= settings.CONFIDENCE_REVIEW_THRESHOLD:
            return "NEEDS_REVIEW"
        else:
            return "MANUAL_VERIFICATION"

    @classmethod
    def evaluate_entry(
        cls,
        name_conf: float,
        amount_conf: float,
        date_conf: float,
        type_conf: float = 0.90,
    ) -> Tuple[float, str]:
        overall = cls.calculate_overall_confidence(name_conf, amount_conf, date_conf, type_conf)
        band = cls.classify_confidence_band(overall)
        return overall, band
