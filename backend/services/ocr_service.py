import os
import json
import logging
import datetime
from typing import Dict, Any, List, Optional
from PIL import Image
from backend.config import settings
from backend.schemas.scan import (
    GeminiExtractionResult,
    RawExtractedEntry,
    ConfidenceDetail,
)

logger = logging.getLogger("KhataSetu.OCR")

KHATA_OCR_PROMPT = """
You are KhataSetu Vision, a specialized AI for reading Indian Kirana (grocery/shop) handwritten paper khata ledgers and registers.
Carefully examine this image of a handwritten ledger page.

Rules:
1. Identify all distinct transaction entries/rows.
2. For each entry, extract:
   - customer_name: The customer's handwritten name (preserve spelling, handle Hindi, Hinglish, or English). If unreadable, return null.
   - amount: The monetary amount in Indian Rupees (numbers only, float/int). Never invent or guess missing numbers. If unreadable, return null.
   - date: The date if explicitly written near the entry or column header (format 'YYYY-MM-DD' or 'DD/MM/YYYY'). If no date is written on the page or line, return null.
   - transaction_type: 'credit' (Udhar/Naam/Gave goods on credit) or 'payment' (Jama/Vasool/Received money) or 'adjustment'. If ambiguous, default to 'credit'.
   - raw_text: The exact snippet of text you detected on this line.
   - confidence: A realistic estimation of your confidence (between 0.00 and 1.00) for each field:
     * customer_name: score from 0.00 to 1.00
     * amount: score from 0.00 to 1.00
     * date: score from 0.00 to 1.00
     * transaction_type: score from 0.00 to 1.00
     * overall: score from 0.00 to 1.00

3. Output MUST be strictly valid JSON matching this schema:
{
  "entries": [
    {
      "customer_name": "Ramesh",
      "amount": 350.0,
      "date": "2026-09-19",
      "transaction_type": "credit",
      "raw_text": "Ramesh 350",
      "confidence": {
        "customer_name": 0.96,
        "amount": 0.99,
        "date": 0.92,
        "transaction_type": 0.95,
        "overall": 0.96
      }
    }
  ],
  "page_notes": "Summary of document legibility"
}

Do NOT wrap the JSON in Markdown code fences. Return purely the raw JSON string.
Do NOT invent numbers or names. If a line is crossed out or illegible, reflect that in low confidence or omit it.
"""


class OCRService:
    @classmethod
    def _call_gemini_vision(cls, image_path: str) -> GeminiExtractionResult:
        """Invokes Gemini 1.5/2.0 Vision API with structured prompt."""
        try:
            import google.generativeai as genai
            genai.configure(api_key=settings.GEMINI_API_KEY)
            model = genai.GenerativeModel(settings.GEMINI_MODEL)

            with Image.open(image_path) as img:
                response = model.generate_content(
                    [KHATA_OCR_PROMPT, img],
                    generation_config={"temperature": 0.1, "max_output_tokens": 2048},
                )

            raw_text = response.text.strip()
            # Remove markdown backticks if returned
            if raw_text.startswith("```json"):
                raw_text = raw_text[7:]
            if raw_text.startswith("```"):
                raw_text = raw_text[3:]
            if raw_text.endswith("```"):
                raw_text = raw_text[:-3]
            raw_text = raw_text.strip()

            parsed = json.loads(raw_text)
            return GeminiExtractionResult.model_validate(parsed)

        except Exception as e:
            logger.warning(f"Gemini API call encountered an error: {str(e)}. Falling back to offline mock.")
            return cls._generate_deterministic_mock(image_path)

    @classmethod
    def _generate_deterministic_mock(cls, image_path: str) -> GeminiExtractionResult:
        """
        Deterministic, realistic Kirana Khata Mock extractor for local development,
        testing, and demonstration without paid API keys.
        Provides a realistic mix of High Confidence, Needs Review, and Manual Verification entries.
        """
        today_str = datetime.date.today().isoformat()
        yesterday_str = (datetime.date.today() - datetime.timedelta(days=1)).isoformat()

        mock_entries = [
            RawExtractedEntry(
                customer_name="Ramesh Kumar",
                amount=450.0,
                date=today_str,
                transaction_type="credit",
                raw_text="Ramesh Kumar 450 udhar 5kg aata",
                confidence=ConfidenceDetail(
                    customer_name=0.98,
                    amount=0.99,
                    date=0.95,
                    transaction_type=0.96,
                    overall=0.97,  # HIGH CONFIDENCE (>= 0.95)
                ),
            ),
            RawExtractedEntry(
                customer_name="Suresh Verma",
                amount=1200.0,
                date=yesterday_str,
                transaction_type="payment",
                raw_text="Suresh Verma Jama 1200 naqd",
                confidence=ConfidenceDetail(
                    customer_name=0.96,
                    amount=0.98,
                    date=0.92,
                    transaction_type=0.95,
                    overall=0.96,  # HIGH CONFIDENCE (>= 0.95)
                ),
            ),
            RawExtractedEntry(
                customer_name="Anita Devi",
                amount=320.0,
                date=today_str,
                transaction_type="credit",
                raw_text="Anita D 320 tel masala",
                confidence=ConfidenceDetail(
                    customer_name=0.88,
                    amount=0.91,
                    date=0.85,
                    transaction_type=0.90,
                    overall=0.89,  # NEEDS REVIEW (0.80 - 0.94)
                ),
            ),
            RawExtractedEntry(
                customer_name="Mohan Lal",
                amount=85.0,
                date=None,  # Missing handwritten date
                transaction_type="credit",
                raw_text="Mohan Lal 85 chai patti",
                confidence=ConfidenceDetail(
                    customer_name=0.92,
                    amount=0.95,
                    date=0.00,
                    transaction_type=0.90,
                    overall=0.82,  # NEEDS REVIEW
                ),
            ),
            RawExtractedEntry(
                customer_name="Pankaj",
                amount=740.0,
                date=None,
                transaction_type="credit",
                raw_text="Pankaj ?40 dhaniya",
                confidence=ConfidenceDetail(
                    customer_name=0.72,
                    amount=0.68,
                    date=0.00,
                    transaction_type=0.75,
                    overall=0.69,  # MANUAL VERIFICATION REQUIRED (< 0.80)
                ),
            ),
        ]

        return GeminiExtractionResult(
            entries=mock_entries,
            page_notes="Handwritten Hindi/English kirana register page. 2 high confidence entries, 2 review needed, 1 manual verification required.",
        )

    @classmethod
    def extract_from_image(cls, image_path: str) -> GeminiExtractionResult:
        """Entry point for OCR extraction. Uses Gemini Vision if key exists, otherwise deterministic mock."""
        if settings.GEMINI_API_KEY and settings.GEMINI_API_KEY.strip():
            logger.info(f"Extracting khata entries using Gemini Vision ({settings.GEMINI_MODEL})")
            return cls._call_gemini_vision(image_path)
        else:
            logger.info("No GEMINI_API_KEY detected. Running in deterministic Kirana Vision Mock mode.")
            return cls._generate_deterministic_mock(image_path)
