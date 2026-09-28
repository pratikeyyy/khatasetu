import os
import json
import time
import datetime
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import List, Optional

from backend.config import settings
from backend.database import get_db
from backend.models.scan import Scan, ScanEntry
from backend.models.customer import Customer
from backend.models.transaction import Transaction
from backend.models.audit import AuditLog
from backend.models.shop import Shop
from backend.models.user import User
from backend.schemas.scan import (
    ScanResponse,
    ScanEntryResponse,
    ScanEntryConfirmRequest,
    ScanEntryEditRequest,
    ScanEntryRejectRequest,
    BatchConfirmHighConfidenceRequest,
)
from backend.services.auth_service import get_current_user, get_current_shop
from backend.services.image_service import ImageService
from backend.services.ocr_service import OCRService
from backend.services.confidence_service import ConfidenceService
from backend.services.matching_service import MatchingService

router = APIRouter(prefix="/scans", tags=["AI Scans & Verification"])


def _build_scan_response(scan: Scan, db: Session, shop_id: int) -> ScanResponse:
    entry_responses = []
    for entry in scan.entries:
        # Find fuzzy suggestions for unconfirmed or pending entries
        fuzzy_suggestions = []
        if entry.status == "PENDING":
            fuzzy_suggestions = MatchingService.find_fuzzy_matches(
                db=db, shop_id=shop_id, extracted_name=entry.extracted_customer_name, threshold=0.70
            )

        matched_name = None
        if entry.matched_customer:
            matched_name = entry.matched_customer.name

        entry_resp = ScanEntryResponse(
            id=entry.id,
            scan_id=entry.scan_id,
            extracted_customer_name=entry.extracted_customer_name,
            extracted_amount=entry.extracted_amount,
            extracted_date=entry.extracted_date,
            extracted_type=entry.extracted_type,
            raw_text=entry.raw_text,
            confidence_customer_name=entry.confidence_customer_name,
            confidence_amount=entry.confidence_amount,
            confidence_date=entry.confidence_date,
            confidence_type=entry.confidence_type,
            confidence_overall=entry.confidence_overall,
            confidence_band=entry.confidence_band,
            is_date_inferred=entry.is_date_inferred,
            status=entry.status,
            matched_customer_id=entry.matched_customer_id,
            matched_customer_name=matched_name,
            fuzzy_suggestions=fuzzy_suggestions,
            corrected_customer_name=entry.corrected_customer_name,
            corrected_amount=entry.corrected_amount,
            corrected_date=entry.corrected_date,
            corrected_type=entry.corrected_type,
            confirmed_at=entry.confirmed_at,
            rejection_reason=entry.rejection_reason,
        )
        entry_responses.append(entry_resp)

    # Relative paths or URL paths for images
    orig_name = os.path.basename(scan.original_image_path)
    proc_name = os.path.basename(scan.processed_image_path) if scan.processed_image_path else None
    thumb_name = os.path.basename(scan.thumbnail_path) if scan.thumbnail_path else None

    return ScanResponse(
        id=scan.id,
        shop_id=scan.shop_id,
        original_image_url=f"/uploads/{orig_name}",
        processed_image_url=f"/uploads/{proc_name}" if proc_name else None,
        thumbnail_url=f"/uploads/{thumb_name}" if thumb_name else None,
        status=scan.status,
        error_message=scan.error_message,
        total_entries=scan.total_entries,
        confirmed_entries=scan.confirmed_entries,
        high_confidence_entries=scan.high_confidence_entries,
        model_name=scan.model_name,
        processing_time_ms=scan.processing_time_ms,
        created_at=scan.created_at,
        entries=entry_responses,
    )


@router.post("/upload", response_model=ScanResponse, status_code=status.HTTP_201_CREATED)
async def upload_scan(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    # 1. Validate file size and extension
    content_type = file.content_type or ""
    if not (content_type.startswith("image/") or file.filename.lower().endswith((".jpg", ".jpeg", ".png", ".webp"))):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported file format. Please upload a clear photo of your paper khata (JPEG, PNG, or WEBP).",
        )

    file_bytes = await file.read()
    if len(file_bytes) > settings.MAX_IMAGE_SIZE_MB * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Image size exceeds the {settings.MAX_IMAGE_SIZE_MB}MB limit.",
        )

    start_time = time.time()

    # 2. Process image (EXIF fix, contrast enhancement, thumbnail)
    try:
        orig_path, proc_path, thumb_path = ImageService.process_and_save_upload(
            file_bytes=file_bytes, original_filename=file.filename
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process image: {str(e)}",
        )

    # 3. Create Scan record
    scan = Scan(
        shop_id=shop.id,
        original_image_path=orig_path,
        processed_image_path=proc_path,
        thumbnail_path=thumb_path,
        status="PROCESSING",
        model_name=settings.GEMINI_MODEL if settings.GEMINI_API_KEY else "kirana-vision-mock",
    )
    db.add(scan)
    db.commit()
    db.refresh(scan)

    # 4. Invoke OCR Service
    try:
        extraction = OCRService.extract_from_image(proc_path)
        scan.raw_ai_response = extraction.model_dump_json()

        high_conf_count = 0
        total_count = 0

        for raw in extraction.entries:
            # Skip empty entries where both name and amount are missing
            if not raw.customer_name and not raw.amount:
                continue

            total_count += 1

            # Parse date or mark as inferred from scan date
            entry_date = None
            is_inferred = False
            if raw.date:
                try:
                    # Attempt ISO parse or standard DD/MM/YYYY
                    if "-" in raw.date:
                        parts = raw.date.split("-")
                        if len(parts[0]) == 4:  # YYYY-MM-DD
                            entry_date = datetime.datetime.strptime(raw.date, "%Y-%m-%d")
                        else:  # DD-MM-YYYY
                            entry_date = datetime.datetime.strptime(raw.date, "%d-%m-%Y")
                    elif "/" in raw.date:
                        entry_date = datetime.datetime.strptime(raw.date, "%d/%m/%Y")
                except Exception:
                    entry_date = datetime.datetime.utcnow()
                    is_inferred = True
            else:
                entry_date = datetime.datetime.utcnow()
                is_inferred = True

            # Evaluate confidence and band
            overall_conf, conf_band = ConfidenceService.evaluate_entry(
                name_conf=raw.confidence.customer_name,
                amount_conf=raw.confidence.amount,
                date_conf=raw.confidence.date if not is_inferred else 0.50,
                type_conf=raw.confidence.transaction_type,
            )

            if conf_band == "HIGH":
                high_conf_count += 1

            # Fuzzy match candidate search
            clean_name = (raw.customer_name or "Unknown").strip()
            norm_name = MatchingService.normalize_name(clean_name)
            matched_customer = db.query(Customer).filter(
                Customer.shop_id == shop.id,
                Customer.normalized_name == norm_name,
                Customer.is_active == True,
            ).first()

            scan_entry = ScanEntry(
                scan_id=scan.id,
                matched_customer_id=matched_customer.id if matched_customer else None,
                extracted_customer_name=clean_name,
                extracted_amount=float(raw.amount or 0.0),
                extracted_date=entry_date,
                extracted_type=(raw.transaction_type or "CREDIT").upper(),
                raw_text=raw.raw_text,
                confidence_customer_name=raw.confidence.customer_name,
                confidence_amount=raw.confidence.amount,
                confidence_date=raw.confidence.date,
                confidence_type=raw.confidence.transaction_type,
                confidence_overall=overall_conf,
                confidence_band=conf_band,
                is_date_inferred=is_inferred,
                status="PENDING",
            )
            db.add(scan_entry)

        duration_ms = int((time.time() - start_time) * 1000)
        scan.processing_time_ms = duration_ms
        scan.total_entries = total_count
        scan.high_confidence_entries = high_conf_count
        scan.status = "REVIEW_NEEDED" if total_count > 0 else "CONFIRMED"
        db.commit()
        db.refresh(scan)

    except Exception as e:
        db.rollback()
        scan.status = "FAILED"
        scan.error_message = f"AI Vision error: {str(e)}"
        db.commit()
        db.refresh(scan)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="We couldn't read this page clearly. Try taking the photo in better lighting and keeping the page flat.",
        )

    return _build_scan_response(scan, db, shop.id)


@router.get("/{scan_id}", response_model=ScanResponse)
def get_scan(
    scan_id: int,
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    scan = db.query(Scan).filter(Scan.id == scan_id, Scan.shop_id == shop.id).first()
    if not scan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Scan record not found.")
    return _build_scan_response(scan, db, shop.id)


@router.get("/", response_model=List[ScanResponse])
def list_scans(
    limit: int = Query(20, le=100),
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    scans = (
        db.query(Scan)
        .filter(Scan.shop_id == shop.id)
        .order_by(desc(Scan.created_at))
        .limit(limit)
        .all()
    )
    return [_build_scan_response(s, db, shop.id) for s in scans]


@router.post("/entries/{entry_id}/confirm", response_model=ScanEntryResponse)
def confirm_scan_entry(
    entry_id: int,
    data: Optional[ScanEntryConfirmRequest] = None,
    user: User = Depends(get_current_user),
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    entry = db.query(ScanEntry).join(Scan).filter(
        ScanEntry.id == entry_id,
        Scan.shop_id == shop.id,
    ).first()

    if not entry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Scan entry not found.")
    if entry.status in ("CONFIRMED", "EDITED_CONFIRMED"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Entry is already confirmed.")

    # 1. Resolve customer
    target_customer = None
    if data and data.customer_id:
        target_customer = db.query(Customer).filter(
            Customer.id == data.customer_id,
            Customer.shop_id == shop.id,
        ).first()

    if not target_customer and entry.matched_customer_id:
        target_customer = db.query(Customer).filter(
            Customer.id == entry.matched_customer_id,
            Customer.shop_id == shop.id,
        ).first()

    if not target_customer:
        # Create new customer with extracted name
        target_customer = Customer(
            shop_id=shop.id,
            name=entry.extracted_customer_name,
            normalized_name=MatchingService.normalize_name(entry.extracted_customer_name),
            credit_balance=0.0,
            total_credit=0.0,
            total_payment=0.0,
        )
        db.add(target_customer)
        db.flush()

    # 2. Create authoritative financial Transaction
    tx = Transaction(
        shop_id=shop.id,
        customer_id=target_customer.id,
        scan_entry_id=entry.id,
        amount=entry.extracted_amount,
        transaction_type=entry.extracted_type,
        date=entry.extracted_date or datetime.datetime.utcnow(),
        notes=f"Confirmed from AI Scan #{entry.scan_id}. Raw text: '{entry.raw_text or ''}'",
        source="AI_SCAN",
    )
    db.add(tx)
    db.flush()

    # 3. Update customer balance
    target_customer.recalculate_balance()

    # 4. Update entry state and audit trail
    entry.status = "CONFIRMED"
    entry.matched_customer_id = target_customer.id
    entry.confirmed_by_user_id = user.id
    entry.confirmed_at = datetime.datetime.utcnow()

    # Update scan confirmed count
    scan = entry.scan
    scan.confirmed_entries = db.query(ScanEntry).filter(
        ScanEntry.scan_id == scan.id,
        ScanEntry.status.in_(["CONFIRMED", "EDITED_CONFIRMED"])
    ).count() + 1
    if scan.confirmed_entries >= scan.total_entries:
        scan.status = "CONFIRMED"

    # 5. Record AuditLog
    audit = AuditLog(
        actor_id=user.id,
        transaction_id=tx.id,
        action="SCAN_CONFIRMED",
        entity_type="SCAN_ENTRY",
        entity_id=entry.id,
        original_value=json.dumps({
            "name": entry.extracted_customer_name,
            "amount": entry.extracted_amount,
            "type": entry.extracted_type,
            "confidence": entry.confidence_overall,
        }),
        new_value=json.dumps({
            "transaction_id": tx.id,
            "customer_id": target_customer.id,
            "confirmed_at": entry.confirmed_at.isoformat(),
        }),
        change_summary=f"Confirmed AI entry: ₹{entry.extracted_amount:.2f} ({entry.extracted_type}) for {target_customer.name}",
    )
    db.add(audit)
    db.commit()
    db.refresh(entry)

    return ScanEntryResponse.model_validate(entry)


@router.post("/entries/{entry_id}/edit-and-confirm", response_model=ScanEntryResponse)
def edit_and_confirm_scan_entry(
    entry_id: int,
    data: ScanEntryEditRequest,
    user: User = Depends(get_current_user),
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    entry = db.query(ScanEntry).join(Scan).filter(
        ScanEntry.id == entry_id,
        Scan.shop_id == shop.id,
    ).first()

    if not entry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Scan entry not found.")
    if entry.status in ("CONFIRMED", "EDITED_CONFIRMED"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Entry is already confirmed.")

    # 1. Resolve customer (existing or newly named)
    target_customer = None
    if data.customer_id:
        target_customer = db.query(Customer).filter(
            Customer.id == data.customer_id,
            Customer.shop_id == shop.id,
        ).first()

    if not target_customer:
        clean_name = data.customer_name.strip()
        norm_name = MatchingService.normalize_name(clean_name)
        target_customer = db.query(Customer).filter(
            Customer.shop_id == shop.id,
            Customer.normalized_name == norm_name,
            Customer.is_active == True,
        ).first()

        if not target_customer:
            target_customer = Customer(
                shop_id=shop.id,
                name=clean_name,
                normalized_name=norm_name,
                credit_balance=0.0,
                total_credit=0.0,
                total_payment=0.0,
            )
            db.add(target_customer)
            db.flush()

    # 2. Record Corrections for Audit Trail (Preserve original extraction!)
    entry.corrected_customer_name = data.customer_name.strip()
    entry.corrected_amount = data.amount
    entry.corrected_date = data.date or entry.extracted_date or datetime.datetime.utcnow()
    entry.corrected_type = data.transaction_type.upper()
    entry.status = "EDITED_CONFIRMED"
    entry.matched_customer_id = target_customer.id
    entry.confirmed_by_user_id = user.id
    entry.confirmed_at = datetime.datetime.utcnow()

    # 3. Create Transaction with corrected financial values
    tx = Transaction(
        shop_id=shop.id,
        customer_id=target_customer.id,
        scan_entry_id=entry.id,
        amount=entry.corrected_amount,
        transaction_type=entry.corrected_type,
        date=entry.corrected_date,
        notes=(
            f"Edited & confirmed from Scan #{entry.scan_id}. "
            f"Original AI: [{entry.extracted_customer_name} ₹{entry.extracted_amount:.2f} {entry.extracted_type}]"
        ),
        source="AI_SCAN",
    )
    db.add(tx)
    db.flush()

    target_customer.recalculate_balance()

    # 4. Audit Log preserving BEFORE and AFTER
    audit = AuditLog(
        actor_id=user.id,
        transaction_id=tx.id,
        action="SCAN_EDITED_CONFIRMED",
        entity_type="SCAN_ENTRY",
        entity_id=entry.id,
        original_value=json.dumps({
            "name": entry.extracted_customer_name,
            "amount": entry.extracted_amount,
            "date": entry.extracted_date.isoformat() if entry.extracted_date else None,
            "type": entry.extracted_type,
            "confidence": entry.confidence_overall,
        }),
        new_value=json.dumps({
            "name": entry.corrected_customer_name,
            "amount": entry.corrected_amount,
            "date": entry.corrected_date.isoformat() if entry.corrected_date else None,
            "type": entry.corrected_type,
            "transaction_id": tx.id,
        }),
        change_summary=(
            f"Human correction on Scan #{entry.scan_id}: "
            f"'{entry.extracted_customer_name}' -> '{entry.corrected_customer_name}', "
            f"₹{entry.extracted_amount:.2f} -> ₹{entry.corrected_amount:.2f}"
        ),
    )
    db.add(audit)

    # Update scan status
    scan = entry.scan
    scan.confirmed_entries = db.query(ScanEntry).filter(
        ScanEntry.scan_id == scan.id,
        ScanEntry.status.in_(["CONFIRMED", "EDITED_CONFIRMED"])
    ).count() + 1
    if scan.confirmed_entries >= scan.total_entries:
        scan.status = "CONFIRMED"

    db.commit()
    db.refresh(entry)
    return ScanEntryResponse.model_validate(entry)


@router.post("/entries/{entry_id}/reject", response_model=ScanEntryResponse)
def reject_scan_entry(
    entry_id: int,
    data: Optional[ScanEntryRejectRequest] = None,
    user: User = Depends(get_current_user),
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    entry = db.query(ScanEntry).join(Scan).filter(
        ScanEntry.id == entry_id,
        Scan.shop_id == shop.id,
    ).first()

    if not entry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Scan entry not found.")

    entry.status = "REJECTED"
    entry.rejection_reason = data.reason if data else "Rejected by shopkeeper"
    entry.confirmed_by_user_id = user.id
    entry.confirmed_at = datetime.datetime.utcnow()

    audit = AuditLog(
        actor_id=user.id,
        action="SCAN_REJECTED",
        entity_type="SCAN_ENTRY",
        entity_id=entry.id,
        original_value=json.dumps({
            "name": entry.extracted_customer_name,
            "amount": entry.extracted_amount,
            "confidence": entry.confidence_overall,
        }),
        change_summary=f"Rejected AI entry: {entry.extracted_customer_name} ₹{entry.extracted_amount:.2f}. Reason: {entry.rejection_reason}",
    )
    db.add(audit)
    db.commit()
    db.refresh(entry)
    return ScanEntryResponse.model_validate(entry)


@router.post("/batch-confirm-high")
def batch_confirm_high_confidence(
    data: BatchConfirmHighConfidenceRequest,
    user: User = Depends(get_current_user),
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    """
    CRITICAL RULE: Confirms ONLY entries that meet the strict high-confidence criteria (>= 0.95).
    Entries with lower confidence MUST remain in PENDING status for human verification.
    """
    entries = db.query(ScanEntry).join(Scan).filter(
        ScanEntry.scan_id == data.scan_id,
        Scan.shop_id == shop.id,
        ScanEntry.status == "PENDING",
        ScanEntry.confidence_band == "HIGH",
    ).all()

    confirmed_count = 0
    for entry in entries:
        # Match or create customer
        clean_name = entry.extracted_customer_name.strip()
        norm_name = MatchingService.normalize_name(clean_name)
        customer = db.query(Customer).filter(
            Customer.shop_id == shop.id,
            Customer.normalized_name == norm_name,
            Customer.is_active == True,
        ).first()

        if not customer:
            customer = Customer(
                shop_id=shop.id,
                name=clean_name,
                normalized_name=norm_name,
                credit_balance=0.0,
                total_credit=0.0,
                total_payment=0.0,
            )
            db.add(customer)
            db.flush()

        tx = Transaction(
            shop_id=shop.id,
            customer_id=customer.id,
            scan_entry_id=entry.id,
            amount=entry.extracted_amount,
            transaction_type=entry.extracted_type,
            date=entry.extracted_date or datetime.datetime.utcnow(),
            notes=f"Auto-confirmed high confidence (>=95%) entry from Scan #{entry.scan_id}",
            source="AI_SCAN",
        )
        db.add(tx)
        customer.recalculate_balance()

        entry.status = "CONFIRMED"
        entry.matched_customer_id = customer.id
        entry.confirmed_by_user_id = user.id
        entry.confirmed_at = datetime.datetime.utcnow()

        audit = AuditLog(
            actor_id=user.id,
            transaction_id=tx.id,
            action="SCAN_HIGH_CONF_BATCH_CONFIRMED",
            entity_type="SCAN_ENTRY",
            entity_id=entry.id,
            change_summary=f"Batch confirmed high-confidence entry: {customer.name} ₹{entry.extracted_amount:.2f}",
        )
        db.add(audit)
        confirmed_count += 1

    db.commit()

    # Update scan record
    scan = db.query(Scan).filter(Scan.id == data.scan_id).first()
    if scan:
        total_confirmed = db.query(ScanEntry).filter(
            ScanEntry.scan_id == scan.id,
            ScanEntry.status.in_(["CONFIRMED", "EDITED_CONFIRMED"]),
        ).count()
        scan.confirmed_entries = total_confirmed
        if scan.confirmed_entries >= scan.total_entries:
            scan.status = "CONFIRMED"
        db.commit()

    return {
        "message": f"Successfully batch confirmed {confirmed_count} high-confidence entries.",
        "confirmed_count": confirmed_count,
        "remaining_pending": scan.total_entries - scan.confirmed_entries if scan else 0,
    }
