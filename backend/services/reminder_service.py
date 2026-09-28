import re
import urllib.parse
from typing import Dict, Any


class ReminderService:
    @staticmethod
    def clean_phone_number(raw_phone: str) -> str:
        """Standardizes phone number for WhatsApp deep link URL."""
        if not raw_phone:
            return ""
        digits = re.sub(r"\D", "", raw_phone)
        # If 10 digits (standard Indian mobile), prepend 91
        if len(digits) == 10:
            return f"91{digits}"
        elif len(digits) == 12 and digits.startswith("91"):
            return digits
        elif len(digits) == 11 and digits.startswith("0"):
            return f"91{digits[1:]}"
        return digits

    @classmethod
    def generate_message_template(
        cls,
        customer_name: str,
        amount: float,
        shop_name: str,
        language: str = "hinglish",
        custom_note: str = None,
    ) -> str:
        formatted_amount = f"{amount:,.2f}"

        if language == "hindi":
            msg = f"नमस्ते {customer_name} जी, आपके खाते में ₹{formatted_amount} शेष हैं। कृपया सुविधानुसार भुगतान कर दें। धन्यवाद — {shop_name}"
        elif language == "english":
            msg = f"Hello {customer_name}, you have a pending balance of ₹{formatted_amount} at {shop_name}. Kindly clear at your convenience. Thank you — {shop_name}"
        else:  # hinglish (Default for Kirana)
            msg = f"Namaste {customer_name} ji, aapke khate mein ₹{formatted_amount} baki hain. Kripya suvidha anusar payment kar dein. Dhanyavaad — {shop_name}"

        if custom_note and custom_note.strip():
            msg += f"\nNote: {custom_note.strip()}"

        return msg

    @classmethod
    def generate_whatsapp_deep_link(
        cls,
        phone: str,
        customer_name: str,
        amount: float,
        shop_name: str,
        language: str = "hinglish",
        custom_note: str = None,
    ) -> Dict[str, Any]:
        """
        Creates a free, direct WhatsApp deep link.
        Shopkeeper clicks this link to launch WhatsApp with prefilled message.
        """
        clean_phone = cls.clean_phone_number(phone)
        message_text = cls.generate_message_template(
            customer_name=customer_name,
            amount=amount,
            shop_name=shop_name,
            language=language,
            custom_note=custom_note,
        )

        encoded_text = urllib.parse.quote(message_text)

        if clean_phone:
            url = f"https://wa.me/{clean_phone}?text={encoded_text}"
        else:
            # WhatsApp share URL if phone is not on file
            url = f"https://wa.me/?text={encoded_text}"

        return {
            "phone": clean_phone,
            "message_text": message_text,
            "whatsapp_url": url,
        }
