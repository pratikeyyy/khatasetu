import logging
from pathlib import Path

from PIL import Image, ImageOps

from backend.config import settings
from backend.schemas.scan import GeminiExtractionResult


logger = logging.getLogger("KhataSetu.OCR")


KHATA_OCR_PROMPT = """
You are KhataSetu Vision, a specialized AI for reading Indian Kirana
(grocery/shop) handwritten paper khata ledgers and registers.

Carefully examine the provided image.

IMPORTANT:
- Read the actual handwritten content from the image.
- Do NOT invent names, amounts, dates, or transactions.
- Do NOT use example values from this prompt as actual data.
- Extract every clearly identifiable transaction row.
- If a field cannot be read reliably, return null.
- Preserve Hindi, Hinglish, and English names as written.
- Pay special attention to handwritten numbers and amounts.

For each transaction entry extract:

1. customer_name
   - Customer's handwritten name.
   - Preserve spelling.
   - Hindi/Hinglish/English is allowed.
   - Return null if unreadable.

2. amount
   - Monetary amount in Indian Rupees.
   - Return only the numeric value.
   - Never guess missing digits.
   - Return null if unreadable.

3. date
   - Date explicitly written near the transaction or in a relevant
     column/header.
   - Use YYYY-MM-DD when possible.
   - If no explicit date is available, return null.
   - Never invent a date.

4. transaction_type
   - "credit" for Udhar / goods given on credit.
   - "payment" for Jama / Vasool / money received.
   - "adjustment" for an adjustment.
   - If genuinely ambiguous, use "credit".

5. raw_text
   - Short exact transcription of the relevant handwritten row.

6. confidence
   - customer_name: 0.00 to 1.00
   - amount: 0.00 to 1.00
   - date: 0.00 to 1.00
   - transaction_type: 0.00 to 1.00
   - overall: 0.00 to 1.00

7. page_notes
   - Brief description of page readability or anything important.

Return JSON matching this exact structure:

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

The example above is ONLY a schema example.
Do not copy its values unless they are actually visible in the image.

Return only structured JSON.
"""


class OCRService:

    @classmethod
    def _call_gemini_vision(
        cls,
        image_path: str,
    ) -> GeminiExtractionResult:

        if not settings.GEMINI_API_KEY:
            raise RuntimeError(
                "Gemini Vision is not configured on the server."
            )

        image_file = Path(image_path)

        if not image_file.exists():
            raise FileNotFoundError(
                f"OCR image not found: {image_file}"
            )

        try:
            from google import genai
            from google.genai import types

            logger.info(
                "Starting Gemini Vision OCR. Model=%s Image=%s",
                settings.GEMINI_MODEL,
                image_file.name,
            )

            # Correct EXIF orientation and convert to RGB.
            # This helps when phone cameras store rotation in EXIF metadata.
            with Image.open(image_file) as original_image:
                image = ImageOps.exif_transpose(original_image)

                if image.mode != "RGB":
                    image = image.convert("RGB")

                # Copy the image so the file remains safely closed.
                image_for_gemini = image.copy()

            client = genai.Client(
                api_key=settings.GEMINI_API_KEY
            )

            response = client.models.generate_content(
                model=settings.GEMINI_MODEL,
                contents=[
                    KHATA_OCR_PROMPT,
                    image_for_gemini,
                ],
                config=types.GenerateContentConfig(
                    temperature=0.1,
                    max_output_tokens=4096,
                    response_mime_type="application/json",
                    response_schema=GeminiExtractionResult,
                ),
            )

            logger.info(
                "Gemini Vision response received successfully."
            )

            # New SDK can return a parsed Pydantic object directly.
            if getattr(response, "parsed", None) is not None:
                parsed_result = response.parsed

                if isinstance(
                    parsed_result,
                    GeminiExtractionResult,
                ):
                    result = parsed_result
                else:
                    result = GeminiExtractionResult.model_validate(
                        parsed_result
                    )

            else:
                raw_text = (response.text or "").strip()

                if not raw_text:
                    raise RuntimeError(
                        "Gemini returned an empty OCR response."
                    )

                result = GeminiExtractionResult.model_validate_json(
                    raw_text
                )

            logger.info(
                "Gemini OCR completed. Entries extracted=%d",
                len(result.entries),
            )

            return result

        except Exception as exc:
            logger.exception(
                "Gemini Vision OCR failed."
            )

            raise RuntimeError(
                f"Gemini Vision OCR failed: {type(exc).__name__}"
            ) from exc

    @classmethod
    def extract_from_image(
        cls,
        image_path: str,
    ) -> GeminiExtractionResult:

        if not settings.GEMINI_API_KEY:
            logger.error(
                "GEMINI_API_KEY is missing."
            )

            raise RuntimeError(
                "Gemini Vision is not configured on the server."
            )

        if not settings.GEMINI_MODEL:
            logger.error(
                "GEMINI_MODEL is missing."
            )

            raise RuntimeError(
                "Gemini model is not configured on the server."
            )

        logger.info(
            "Using REAL Gemini Vision OCR. Model=%s",
            settings.GEMINI_MODEL,
        )

        return cls._call_gemini_vision(
            image_path
        )