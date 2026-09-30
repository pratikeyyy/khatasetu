import json
import logging

from PIL import Image

from backend.config import settings
from backend.schemas.scan import (
    GeminiExtractionResult,
)


logger = logging.getLogger("KhataSetu.OCR")


KHATA_OCR_PROMPT = """
You are KhataSetu Vision, a specialized AI for reading Indian Kirana
(grocery/shop) handwritten paper khata ledgers and registers.

Carefully examine this image of a handwritten ledger page.

Rules:

1. Identify all distinct transaction entries/rows.

2. For each entry, extract:

   - customer_name:
     The customer's handwritten name.
     Preserve spelling.
     Handle Hindi, Hinglish, or English.
     If unreadable, return null.

   - amount:
     The monetary amount in Indian Rupees.
     Numbers only, float/int.
     Never invent or guess missing numbers.
     If unreadable, return null.

   - date:
     The date if explicitly written near the entry or column header.
     Format YYYY-MM-DD or DD/MM/YYYY.
     If no date is written on the page or line, return null.

   - transaction_type:
     "credit" (Udhar/Naam/Gave goods on credit)
     or
     "payment" (Jama/Vasool/Received money)
     or
     "adjustment".

     If ambiguous, default to "credit".

   - raw_text:
     The exact snippet of text detected on this line.

   - confidence:
     A realistic estimation of confidence between 0.00 and 1.00
     for each field:

       customer_name: 0.00 to 1.00
       amount: 0.00 to 1.00
       date: 0.00 to 1.00
       transaction_type: 0.00 to 1.00
       overall: 0.00 to 1.00

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

Do NOT wrap the JSON in Markdown code fences.
Return purely the raw JSON string.

Do NOT invent numbers or names.

If a line is crossed out or illegible,
reflect that in low confidence or omit it.
"""


class OCRService:

    @classmethod
    def _call_gemini_vision(
        cls,
        image_path: str,
    ) -> GeminiExtractionResult:
        """
        Call the real Gemini Vision API.

        Production behavior:
        - Gemini must be configured.
        - No mock/fake OCR fallback.
        - Any Gemini/API/JSON/schema failure is raised to the caller.
        """

        if not settings.GEMINI_API_KEY:
            raise RuntimeError(
                "Gemini Vision is not configured. "
                "GEMINI_API_KEY is missing."
            )

        try:
            import google.generativeai as genai

            genai.configure(
                api_key=settings.GEMINI_API_KEY
            )

            model = genai.GenerativeModel(
                settings.GEMINI_MODEL
            )

            logger.info(
                "Calling Gemini Vision model: %s",
                settings.GEMINI_MODEL,
            )

            with Image.open(image_path) as img:
                response = model.generate_content(
                    [
                        KHATA_OCR_PROMPT,
                        img,
                    ],
                    generation_config={
                        "temperature": 0.1,
                        "max_output_tokens": 2048,
                    },
                )

            raw_text = response.text.strip()

            # Gemini sometimes returns JSON inside markdown fences.
            if raw_text.startswith("```json"):
                raw_text = raw_text[7:]

            elif raw_text.startswith("```"):
                raw_text = raw_text[3:]

            if raw_text.endswith("```"):
                raw_text = raw_text[:-3]

            raw_text = raw_text.strip()

            if not raw_text:
                raise RuntimeError(
                    "Gemini returned an empty OCR response."
                )

            parsed = json.loads(raw_text)

            result = GeminiExtractionResult.model_validate(
                parsed
            )

            logger.info(
                "Gemini Vision OCR completed successfully. "
                "Entries extracted: %d",
                len(result.entries),
            )

            return result

        except json.JSONDecodeError as exc:
            logger.error(
                "Gemini returned invalid JSON: %s",
                exc,
            )
            raise RuntimeError(
                "Gemini returned an invalid OCR response."
            ) from exc

        except Exception as exc:
            logger.error(
                "Gemini Vision OCR failed: %s",
                exc,
                exc_info=True,
            )

            raise RuntimeError(
                "Gemini Vision OCR failed. "
                "Please check the internet connection, "
                "Gemini API key, model configuration, "
                "or try the scan again."
            ) from exc

    @classmethod
    def extract_from_image(
        cls,
        image_path: str,
    ) -> GeminiExtractionResult:
        """
        Production OCR entry point.

        The scanner always uses real Gemini Vision.
        There is intentionally no mock/fake fallback.
        """

        if not settings.GEMINI_API_KEY:
            logger.error(
                "GEMINI_API_KEY is not configured."
            )

            raise RuntimeError(
                "Gemini Vision is not configured on the server."
            )

        logger.info(
            "Extracting Khata entries using real Gemini Vision "
            "(%s)",
            settings.GEMINI_MODEL,
        )

        return cls._call_gemini_vision(
            image_path
        )