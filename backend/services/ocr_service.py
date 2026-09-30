import io
import json
import logging
import random
import time
from typing import Any, Optional

from PIL import Image, ImageOps

from backend.config import settings
from backend.schemas.scan import GeminiExtractionResult

logger = logging.getLogger("KhataSetu.OCR")


# ============================================================
# KHATASETU GEMINI VISION PROMPT
# ============================================================

KHATA_OCR_PROMPT = """
You are KhataSetu Vision, an AI specialized in reading Indian
Kirana shop handwritten paper khata/ledger/register pages.

Carefully inspect the provided image.

Your job is to extract REAL information visible in the image.
Never invent, guess, or fabricate a customer name, amount, date,
or transaction.

RULES:

1. Identify every distinct transaction row/entry that is actually
   visible on the page.

2. For every transaction extract:

   customer_name:
   - The handwritten customer's name.
   - Preserve the spelling as closely as possible.
   - Hindi, Hinglish, and English are allowed.
   - If the name cannot be read reliably, return null.

   amount:
   - Monetary amount in Indian Rupees.
   - Return only the numeric value.
   - Example: ₹450 -> 450.0
   - Never guess a missing digit.
   - If unreadable, return null.

   date:
   - Extract a date only when it is actually visible on the page
     or clearly associated with the transaction.
   - Prefer YYYY-MM-DD.
   - DD/MM/YYYY is also acceptable.
   - If no date is visible, return null.
   - NEVER invent today's date.

   transaction_type:
   - "credit" for Udhar / goods given on credit.
   - "payment" for Jama / Vasooli / money received.
   - "adjustment" for an actual adjustment entry.
   - If genuinely ambiguous, use "credit".

   raw_text:
   - The actual handwritten text/snippet corresponding to the row.

3. Confidence values must represent how clearly the information
   is visible in the image.

   customer_name: 0.00 to 1.00
   amount: 0.00 to 1.00
   date: 0.00 to 1.00
   transaction_type: 0.00 to 1.00
   overall: 0.00 to 1.00

4. Do not create entries from printed labels, column headings,
   page numbers, totals, or unrelated text.

5. Do not duplicate a transaction row.

6. If a row is crossed out, unreadable, or clearly not a transaction,
   omit it unless useful information can still be reliably extracted.

7. Accuracy is more important than filling every field.

8. Return ONLY the requested structured JSON response.
"""


# ============================================================
# MODEL CASCADE
# ============================================================
#
# All of these are current Gemini 3 Flash-family models.
#
# We intentionally use a cascade instead of hammering one model
# repeatedly when Google's service returns 503.
#
# Higher-quality models are attempted first.
# Lower-cost / lighter models are used only if necessary.
# ============================================================

MODEL_CASCADE = [
    "gemini-3.8-flash",
    "gemini-3.7-flash",
    "gemini-3.6-flash",
    "gemini-3.5-flash",
    "gemini-3.5-flash-lite",
    "gemini-3.1-flash-lite",
]


# Number of application-level attempts per model.
#
# The Google GenAI SDK normally performs its own retries for 5xx.
# We explicitly set SDK attempts=1 below so that our cascade controls
# retry behavior instead of creating nested retry loops.
MODEL_ATTEMPTS = 2

# Application-level delays.
# Jitter prevents repeated requests from hitting Google's service
# at exactly the same time.
RETRY_DELAYS = [2.0, 5.0]

# Gemini request timeout in milliseconds.
REQUEST_TIMEOUT_MS = 90000

# Maximum image dimension sent to Gemini.
MAX_IMAGE_DIMENSION = 4096


class OCRService:
    """
    Production Gemini Vision OCR service for KhataSetu.

    Important:
    - No deterministic mock data.
    - No fake fallback.
    - Gemini Vision only.
    - Multiple real Gemini models are used as a reliability cascade.
    """

    # --------------------------------------------------------
    # Image preparation
    # --------------------------------------------------------

    @classmethod
    def _prepare_image(cls, image_path: str) -> tuple[bytes, str]:
        """
        Opens the processed image, fixes EXIF orientation, converts it
        to RGB, limits its dimensions, and returns JPEG bytes.
        """

        logger.info(
            "Preparing image for Gemini Vision: %s",
            image_path,
        )

        with Image.open(image_path) as source:
            image = ImageOps.exif_transpose(source)

            if image.mode != "RGB":
                image = image.convert("RGB")
            else:
                image = image.copy()

            # Prevent unnecessarily huge uploads.
            image.thumbnail(
                (MAX_IMAGE_DIMENSION, MAX_IMAGE_DIMENSION),
                Image.Resampling.LANCZOS,
            )

            buffer = io.BytesIO()

            image.save(
                buffer,
                format="JPEG",
                quality=95,
                optimize=True,
            )

            image_bytes = buffer.getvalue()

        logger.info(
            "Gemini image prepared successfully: %d bytes",
            len(image_bytes),
        )

        return image_bytes, "image/jpeg"

    # --------------------------------------------------------
    # Retry classification
    # --------------------------------------------------------

    @classmethod
    def _is_retryable_error(cls, error: Exception) -> bool:
        """
        Returns True for temporary Gemini/API/network errors.
        """

        text = str(error).lower()

        retry_markers = (
            "408",
            "429",
            "500",
            "502",
            "503",
            "504",
            "timeout",
            "timed out",
            "temporarily unavailable",
            "temporary error",
            "service unavailable",
            "unavailable",
            "resource exhausted",
        )

        return any(marker in text for marker in retry_markers)

    # --------------------------------------------------------
    # Single Gemini request
    # --------------------------------------------------------

    @classmethod
    def _generate_with_model(
        cls,
        client: Any,
        model_name: str,
        image_bytes: bytes,
        mime_type: str,
    ) -> GeminiExtractionResult:
        """
        Makes exactly one application-level Gemini request.

        SDK retry is explicitly disabled by setting attempts=1.
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
                types.Part.from_bytes(
                    data=image_bytes,
                    mime_type=mime_type,
                ),
            ],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=GeminiExtractionResult,
                temperature=0.1,
                max_output_tokens=4096,
            ),
        )

        # New SDK can expose parsed structured output directly.
        parsed = getattr(response, "parsed", None)

        if parsed is not None:
            if isinstance(parsed, GeminiExtractionResult):
                return parsed

            if isinstance(parsed, dict):
                return GeminiExtractionResult.model_validate(parsed)

        # Safe fallback to response.text.
        raw_text = getattr(response, "text", None)

        if not raw_text:
            raise RuntimeError(
                f"Gemini model {model_name} returned an empty response."
            )

        raw_text = raw_text.strip()

        # Defensive handling in case a model returns markdown anyway.
        if raw_text.startswith("```json"):
            raw_text = raw_text[7:]

        elif raw_text.startswith("```"):
            raw_text = raw_text[3:]

        if raw_text.endswith("```"):
            raw_text = raw_text[:-3]

        raw_text = raw_text.strip()

        try:
            parsed_json = json.loads(raw_text)
        except json.JSONDecodeError as exc:
            raise RuntimeError(
                f"Gemini returned invalid JSON from model {model_name}: "
                f"{exc}"
            ) from exc

        return GeminiExtractionResult.model_validate(parsed_json)

    # --------------------------------------------------------
    # Main Gemini cascade
    # --------------------------------------------------------

    @classmethod
    def _call_gemini_vision(
        cls,
        image_path: str,
    ) -> GeminiExtractionResult:
        """
        Production Gemini Vision call.

        Cascade:

            3.8 Flash
                ↓
            3.7 Flash
                ↓
            3.6 Flash
                ↓
            3.5 Flash
                ↓
            3.5 Flash-Lite
                ↓
            3.1 Flash-Lite

        No mock data is ever returned.
        """

        if not settings.GEMINI_API_KEY:
            raise RuntimeError(
                "GEMINI_API_KEY is not configured."
            )

        from google import genai
        from google.genai import types

        logger.info(
            "Starting production Gemini Vision OCR. "
            "Model cascade=%s",
            " -> ".join(MODEL_CASCADE),
        )

        # ----------------------------------------------------
        # Prepare image ONCE.
        # ----------------------------------------------------

        image_bytes, mime_type = cls._prepare_image(image_path)

        # ----------------------------------------------------
        # Create client.
        #
        # attempts=1 is deliberate.
        # Google SDK otherwise performs its own transient-error
        # retries, which combined with application retries caused
        # excessive repeated calls in the previous implementation.
        # ----------------------------------------------------

        client = genai.Client(
            api_key=settings.GEMINI_API_KEY,
            http_options=types.HttpOptions(
                timeout=REQUEST_TIMEOUT_MS,
                retry_options=types.HttpRetryOptions(
                    attempts=1,
                ),
            ),
        )

        last_error: Optional[Exception] = None

        # ----------------------------------------------------
        # Model cascade
        # ----------------------------------------------------

        for model_index, model_name in enumerate(MODEL_CASCADE):

            is_primary = model_index == 0

            if is_primary:
                logger.info(
                    "Trying primary Gemini model: %s",
                    model_name,
                )
            else:
                logger.warning(
                    "Switching to Gemini fallback model %d/%d: %s",
                    model_index + 1,
                    len(MODEL_CASCADE),
                    model_name,
                )

            for attempt in range(1, MODEL_ATTEMPTS + 1):

                logger.info(
                    "Gemini model attempt %d/%d. Model=%s",
                    attempt,
                    MODEL_ATTEMPTS,
                    model_name,
                )

                try:
                    result = cls._generate_with_model(
                        client=client,
                        model_name=model_name,
                        image_bytes=image_bytes,
                        mime_type=mime_type,
                    )

                    logger.info(
                        "Gemini Vision OCR SUCCESS. Model=%s Entries=%d",
                        model_name,
                        len(result.entries),
                    )

                    return result

                except Exception as exc:
                    last_error = exc

                    retryable = cls._is_retryable_error(exc)

                    if retryable:
                        logger.warning(
                            "Temporary Gemini error. "
                            "Model=%s Attempt=%d/%d Error=%s",
                            model_name,
                            attempt,
                            MODEL_ATTEMPTS,
                            str(exc),
                        )

                        # If another attempt remains for this model,
                        # wait before retrying it.
                        if attempt < MODEL_ATTEMPTS:
                            delay = RETRY_DELAYS[
                                min(
                                    attempt - 1,
                                    len(RETRY_DELAYS) - 1,
                                )
                            ]

                            # Small jitter.
                            delay += random.uniform(0.0, 1.0)

                            logger.info(
                                "Waiting %.1f seconds before retrying "
                                "model %s...",
                                delay,
                                model_name,
                            )

                            time.sleep(delay)

                            continue

                        # Model exhausted.
                        logger.warning(
                            "Model %s exhausted its attempts. "
                            "Moving to next Gemini model.",
                            model_name,
                        )

                        break

                    # ------------------------------------------------
                    # Non-retryable error.
                    #
                    # Examples: invalid API key, invalid request,
                    # malformed schema, permission error.
                    #
                    # Retrying another model will not fix these.
                    # ------------------------------------------------

                    logger.error(
                        "Non-retryable Gemini error from model %s: %s",
                        model_name,
                        str(exc),
                        exc_info=True,
                    )

                    raise RuntimeError(
                        f"Gemini Vision request failed: {exc}"
                    ) from exc

        # --------------------------------------------------------
        # Everything failed.
        #
        # IMPORTANT:
        # We DO NOT return fake/mock data.
        # --------------------------------------------------------

        logger.error(
            "ALL Gemini Vision models failed. "
            "Last error: %s",
            str(last_error),
            exc_info=True,
        )

        raise RuntimeError(
            "Gemini Vision is temporarily unavailable across all "
            "configured Gemini models. Please try the scan again "
            "in a few moments."
        ) from last_error

    # --------------------------------------------------------
    # Public entry point used by scan router
    # --------------------------------------------------------

    @classmethod
    def extract_from_image(
        cls,
        image_path: str,
    ) -> GeminiExtractionResult:
        """
        Public OCR entry point.

        Production behavior is always real Gemini Vision when
        GEMINI_API_KEY is configured.

        There is intentionally NO offline mock fallback.
        """

        if not settings.GEMINI_API_KEY:
            logger.error(
                "GEMINI_API_KEY is missing. "
                "Cannot perform production OCR."
            )

            raise RuntimeError(
                "Gemini Vision is not configured on the server."
            )

        return cls._call_gemini_vision(image_path)