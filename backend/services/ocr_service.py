import logging
import time
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

Do NOT invent names, amounts, dates, or transactions.
"""


# Main production model.
PRIMARY_MODEL = "gemini-3.8-flash"

# Secondary stable model used only when the primary model repeatedly
# returns a temporary 503/availability error.
FALLBACK_MODEL = "gemini-3.7-flash"

# Number of application-level attempts for the primary model.
PRIMARY_RETRIES = 3

# Delay between primary retries.
RETRY_DELAYS = [5, 10]


class OCRService:

    @staticmethod
    def _is_retryable_error(exc: Exception) -> bool:
        """
        Return True only for temporary Gemini/API availability errors.

        We retry:
        - 408 Request Timeout
        - 429 Rate Limit
        - 500 Internal Server Error
        - 502 Bad Gateway
        - 503 Service Unavailable
        - 504 Gateway Timeout

        We do NOT retry authentication, permission, malformed-request,
        or schema errors.
        """

        status_code = getattr(exc, "status_code", None)

        if status_code in {
            408,
            429,
            500,
            502,
            503,
            504,
        }:
            return True

        # Some SDK exceptions expose the code differently.
        code = getattr(exc, "code", None)

        if code in {
            408,
            429,
            500,
            502,
            503,
            504,
        }:
            return True

        error_text = str(exc).upper()

        temporary_markers = (
            "503",
            "UNAVAILABLE",
            "SERVICE_UNAVAILABLE",
            "429",
            "RESOURCE_EXHAUSTED",
            "500",
            "INTERNAL",
            "502",
            "BAD_GATEWAY",
            "504",
            "DEADLINE_EXCEEDED",
            "408",
            "TIMEOUT",
        )

        return any(
            marker in error_text
            for marker in temporary_markers
        )

    @classmethod
    def _generate_with_model(
        cls,
        client,
        model_name: str,
        image,
    ) -> GeminiExtractionResult:
        """
        Send the image to Gemini and validate the structured response.
        """

        from google.genai import types

        logger.info(
            "Calling Gemini Vision model: %s",
            model_name,
        )

        response = client.models.generate_content(
            model=model_name,
            contents=[
                KHATA_OCR_PROMPT,
                image,
            ],
            config=types.GenerateContentConfig(
                max_output_tokens=4096,
                response_mime_type="application/json",
                response_schema=GeminiExtractionResult,
            ),
        )

        # Preferred path when the SDK returns parsed structured output.
        parsed = getattr(response, "parsed", None)

        if parsed is not None:

            if isinstance(
                parsed,
                GeminiExtractionResult,
            ):
                result = parsed

            else:
                result = GeminiExtractionResult.model_validate(
                    parsed
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
            "Gemini OCR successful. Model=%s Entries=%d",
            model_name,
            len(result.entries),
        )

        return result

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
                "Preparing image for Gemini Vision: %s",
                image_file.name,
            )

            # Correct phone-camera EXIF rotation.
            with Image.open(image_file) as original_image:

                image = ImageOps.exif_transpose(
                    original_image
                )

                if image.mode != "RGB":
                    image = image.convert("RGB")

                # Keep a standalone copy after closing the source file.
                image_for_gemini = image.copy()

            client = genai.Client(
                api_key=settings.GEMINI_API_KEY,
                http_options=types.HttpOptions(
                    timeout=120000,
                ),
            )

            # ---------------------------------------------------------
            # ATTEMPT 1..3: PRIMARY MODEL
            # ---------------------------------------------------------

            last_exception = None

            for attempt in range(
                PRIMARY_RETRIES
            ):

                try:

                    logger.info(
                        "Gemini primary attempt %d/%d. Model=%s",
                        attempt + 1,
                        PRIMARY_RETRIES,
                        PRIMARY_MODEL,
                    )

                    return cls._generate_with_model(
                        client=client,
                        model_name=PRIMARY_MODEL,
                        image=image_for_gemini,
                    )

                except Exception as exc:

                    last_exception = exc

                    if not cls._is_retryable_error(
                        exc
                    ):
                        logger.exception(
                            "Non-retryable Gemini error."
                        )
                        raise

                    logger.warning(
                        "Gemini temporary error on attempt %d/%d: %s",
                        attempt + 1,
                        PRIMARY_RETRIES,
                        exc,
                    )

                    if attempt < PRIMARY_RETRIES - 1:

                        delay = RETRY_DELAYS[
                            attempt
                        ]

                        logger.info(
                            "Retrying Gemini in %d seconds...",
                            delay,
                        )

                        time.sleep(delay)

            # ---------------------------------------------------------
            # FALLBACK MODEL
            # ---------------------------------------------------------

            logger.warning(
                "Primary Gemini model remained unavailable. "
                "Trying fallback model: %s",
                FALLBACK_MODEL,
            )

            try:

                return cls._generate_with_model(
                    client=client,
                    model_name=FALLBACK_MODEL,
                    image=image_for_gemini,
                )

            except Exception as fallback_exc:

                logger.exception(
                    "Gemini fallback model also failed."
                )

                raise RuntimeError(
                    "Gemini Vision is temporarily unavailable. "
                    "Please try scanning again in a few moments."
                ) from fallback_exc

        except RuntimeError:
            raise

        except Exception as exc:

            logger.exception(
                "Gemini Vision OCR failed."
            )

            raise RuntimeError(
                f"Gemini Vision OCR failed: "
                f"{type(exc).__name__}"
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

        logger.info(
            "Starting production Gemini Vision OCR. "
            "Primary=%s Fallback=%s",
            PRIMARY_MODEL,
            FALLBACK_MODEL,
        )

        return cls._call_gemini_vision(
            image_path
        )