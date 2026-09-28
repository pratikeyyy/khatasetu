import os
import uuid
from PIL import Image, ImageOps, ImageEnhance
from typing import Tuple
from backend.config import settings


class ImageService:
    @staticmethod
    def fix_exif_orientation(image: Image.Image) -> Image.Image:
        """Correct smartphone camera orientation using EXIF tags."""
        try:
            return ImageOps.exif_transpose(image)
        except Exception:
            return image

    @classmethod
    def process_and_save_upload(
        cls, file_bytes: bytes, original_filename: str
    ) -> Tuple[str, str, str]:
        """
        Saves original uploaded image, creates an enhanced version for AI vision,
        and generates a lightweight thumbnail for mobile UI.
        Returns: (original_path, processed_path, thumbnail_path)
        """
        ext = os.path.splitext(original_filename)[1].lower()
        if ext not in [".jpg", ".jpeg", ".png", ".webp"]:
            ext = ".jpg"

        file_id = str(uuid.uuid4())
        original_filename = f"{file_id}_original{ext}"
        processed_filename = f"{file_id}_enhanced.jpg"
        thumbnail_filename = f"{file_id}_thumb.jpg"

        original_path = os.path.join(settings.UPLOAD_DIR, original_filename)
        processed_path = os.path.join(settings.UPLOAD_DIR, processed_filename)
        thumbnail_path = os.path.join(settings.UPLOAD_DIR, thumbnail_filename)

        # 1. Save raw original
        with open(original_path, "wb") as f:
            f.write(file_bytes)

        # 2. Open with PIL for processing
        with Image.open(original_path) as img:
            img = cls.fix_exif_orientation(img)
            if img.mode in ("RGBA", "P"):
                img = img.convert("RGB")

            # Resize if overly large (> 2500px) to preserve memory & bandwidth while maintaining legibility
            max_dim = 2500
            if max(img.size) > max_dim:
                img.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)

            # Contrast & Sharpness enhancement for handwritten kirana ink/pencil
            enhancer = ImageEnhance.Contrast(img)
            enhanced = enhancer.enhance(1.3)
            sharpener = ImageEnhance.Sharpness(enhanced)
            enhanced = sharpener.enhance(1.2)

            enhanced.save(processed_path, "JPEG", quality=88, optimize=True)

            # 3. Create mobile-friendly thumbnail
            thumb = img.copy()
            thumb.thumbnail((400, 400), Image.Resampling.LANCZOS)
            thumb.save(thumbnail_path, "JPEG", quality=80, optimize=True)

        return original_path, processed_path, thumbnail_path
