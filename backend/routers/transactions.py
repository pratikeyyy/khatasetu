import json
import datetime
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import List, Optional
from backend.database import get_db
from backend.models.transaction import Transaction
from backend.models.customer import Customer
from backend.models.shop import Shop
from backend.models.user import User
from backend.models.audit import AuditLog
from backend.schemas.transaction import (
    TransactionCreate,
    TransactionResponse,
    DuplicateCheckResponse,
)
from backend.services.auth_service import get_current_user, get_current_shop
from backend.services.matching_service import MatchingService

router = APIRouter(prefix="/transactions", tags=["Transactions & Ledger"])


@router.get("/", response_model=List[TransactionResponse])
def list_transactions(
    customer_id: Optional[int] = Query(None),
    transaction_type: Optional[str] = Query(None, description="CREDIT, PAYMENT, ADJUSTMENT"),
    source: Optional[str] = Query(None, description="MANUAL, AI_SCAN"),
    start_date: Optional[datetime.date] = Query(None),
    end_date: Optional[datetime.date] = Query(None),
    limit: int = Query(100, le=500),
    offset: int = Query(0),
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    query = db.query(Transaction).filter(Transaction.shop_id == shop.id)

    if customer_id:
        query = query.filter(Transaction.customer_id == customer_id)
    if transaction_type:
        query = query.filter(Transaction.transaction_type == transaction_type.upper())
    if source:
        query = query.filter(Transaction.source == source.upper())
    if start_date:
        query = query.filter(Transaction.date >= datetime.datetime.combine(start_date, datetime.time.min))
    if end_date:
        query = query.filter(Transaction.date <= datetime.datetime.combine(end_date, datetime.time.max))

    txs = query.order_by(desc(Transaction.date), desc(Transaction.id)).offset(offset).limit(limit).all()

    responses = []
    for tx in txs:
        resp = TransactionResponse(
            id=tx.id,
            shop_id=tx.shop_id,
            customer_id=tx.customer_id,
            customer_name=tx.customer.name if tx.customer else "Unknown",
            scan_entry_id=tx.scan_entry_id,
            amount=tx.amount,
            transaction_type=tx.transaction_type,
            date=tx.date,
            notes=tx.notes,
            source=tx.source,
            created_at=tx.created_at,
            updated_at=tx.updated_at,
        )
        responses.append(resp)

    return responses


@router.post("/check-duplicate", response_model=DuplicateCheckResponse)
def check_duplicate(
    data: TransactionCreate,
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    is_dup, existing, msg = MatchingService.check_duplicate_transaction(
        db=db,
        shop_id=shop.id,
        customer_id=data.customer_id,
        amount=data.amount,
        date=data.date or datetime.datetime.utcnow(),
        tx_type=data.transaction_type,
    )
    return DuplicateCheckResponse(
        is_possible_duplicate=is_dup,
        existing_transaction_id=existing.id if existing else None,
        existing_amount=existing.amount if existing else None,
        existing_date=existing.date if existing else None,
        message=msg if is_dup else "No duplicate found",
    )


@router.post("/", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED)
def create_transaction(
    data: TransactionCreate,
    force: bool = Query(False, description="Set true to override duplicate warning"),
    user: User = Depends(get_current_user),
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    customer = db.query(Customer).filter(
        Customer.id == data.customer_id,
        Customer.shop_id == shop.id,
    ).first()

    if not customer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer not found in this shop.")

    tx_date = data.date or datetime.datetime.utcnow()

    # Check duplicate unless explicitly forced
    if not force:
        is_dup, existing, msg = MatchingService.check_duplicate_transaction(
            db=db,
            shop_id=shop.id,
            customer_id=customer.id,
            amount=data.amount,
            date=tx_date,
            tx_type=data.transaction_type,
        )
        if is_dup:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={"message": msg, "existing_id": existing.id, "can_force": True},
            )

    tx = Transaction(
        shop_id=shop.id,
        customer_id=customer.id,
        amount=data.amount,
        transaction_type=data.transaction_type,
        date=tx_date,
        notes=data.notes.strip() if data.notes else None,
        source="MANUAL",
    )
    db.add(tx)
    db.flush()

    # Recalculate customer balance authoritatively
    customer.recalculate_balance()

    # Write audit log
    audit = AuditLog(
        actor_id=user.id,
        transaction_id=tx.id,
        action="TRANSACTION_CREATED",
        entity_type="TRANSACTION",
        entity_id=tx.id,
        new_value=json.dumps({
            "amount": tx.amount,
            "type": tx.transaction_type,
            "customer_id": customer.id,
            "customer_name": customer.name,
            "source": "MANUAL",
        }),
        change_summary=f"Manual {tx.transaction_type} of ₹{tx.amount:.2f} recorded for {customer.name}",
    )
    db.add(audit)
    db.commit()
    db.refresh(tx)

    return TransactionResponse(
        id=tx.id,
        shop_id=tx.shop_id,
        customer_id=tx.customer_id,
        customer_name=customer.name,
        scan_entry_id=tx.scan_entry_id,
        amount=tx.amount,
        transaction_type=tx.transaction_type,
        date=tx.date,
        notes=tx.notes,
        source=tx.source,
        created_at=tx.created_at,
        updated_at=tx.updated_at,
    )


@router.delete("/{transaction_id}")
def delete_transaction(
    transaction_id: int,
    user: User = Depends(get_current_user),
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    tx = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.shop_id == shop.id,
    ).first()

    if not tx:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found.")

    customer = tx.customer
    tx_summary = f"{tx.transaction_type} of ₹{tx.amount:.2f} on {tx.date}"

    # Write audit log
    audit = AuditLog(
        actor_id=user.id,
        action="TRANSACTION_DELETED",
        entity_type="TRANSACTION",
        entity_id=tx.id,
        original_value=json.dumps({"amount": tx.amount, "type": tx.transaction_type, "customer_id": tx.customer_id}),
        change_summary=f"Deleted {tx_summary} for customer {customer.name if customer else 'Unknown'}",
    )
    db.add(audit)

    db.delete(tx)
    db.flush()

    if customer:
        customer.recalculate_balance()

    db.commit()
    return {"message": "Transaction deleted successfully and customer balance recalculated."}
