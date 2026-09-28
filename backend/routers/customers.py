from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc, asc
from typing import List, Optional
from backend.database import get_db
from backend.models.customer import Customer
from backend.models.shop import Shop
from backend.schemas.customer import (
    CustomerCreate,
    CustomerUpdate,
    CustomerResponse,
    CustomerDetailResponse,
    FuzzyMatchCandidate,
)
from backend.services.auth_service import get_current_shop
from backend.services.matching_service import MatchingService

router = APIRouter(prefix="/customers", tags=["Customers"])


@router.get("/", response_model=List[CustomerResponse])
def list_customers(
    search: Optional[str] = Query(None, description="Search by name or phone"),
    has_balance: Optional[bool] = Query(None, description="Filter customers with positive outstanding balance"),
    sort_by: str = Query("name", description="name, balance_desc, balance_asc, recent"),
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    query = db.query(Customer).filter(Customer.shop_id == shop.id, Customer.is_active == True)

    if search and search.strip():
        term = f"%{search.strip().lower()}%"
        query = query.filter(
            or_(
                Customer.name.ilike(term),
                Customer.normalized_name.ilike(term),
                Customer.phone.ilike(term),
            )
        )

    if has_balance is True:
        query = query.filter(Customer.credit_balance > 0)
    elif has_balance is False:
        query = query.filter(Customer.credit_balance <= 0)

    if sort_by == "balance_desc":
        query = query.order_by(desc(Customer.credit_balance))
    elif sort_by == "balance_asc":
        query = query.order_by(asc(Customer.credit_balance))
    elif sort_by == "recent":
        query = query.order_by(desc(Customer.updated_at))
    else:
        query = query.order_by(asc(Customer.name))

    return query.all()


@router.post("/", response_model=CustomerResponse, status_code=status.HTTP_201_CREATED)
def create_customer(
    data: CustomerCreate,
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    clean_name = data.name.strip()
    norm_name = MatchingService.normalize_name(clean_name)

    # Check for exact duplicate in this shop
    existing = db.query(Customer).filter(
        Customer.shop_id == shop.id,
        Customer.normalized_name == norm_name,
        Customer.is_active == True,
    ).first()

    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"A customer named '{existing.name}' already exists in your khata.",
        )

    customer = Customer(
        shop_id=shop.id,
        name=clean_name,
        normalized_name=norm_name,
        phone=data.phone.strip() if data.phone else None,
        address=data.address.strip() if data.address else None,
        notes=data.notes.strip() if data.notes else None,
        credit_balance=0.0,
        total_credit=0.0,
        total_payment=0.0,
    )
    db.add(customer)
    db.commit()
    db.refresh(customer)
    return customer


@router.get("/{customer_id}", response_model=CustomerDetailResponse)
def get_customer(
    customer_id: int,
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    customer = db.query(Customer).filter(
        Customer.id == customer_id,
        Customer.shop_id == shop.id,
    ).first()

    if not customer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer not found.")

    # Calculate fuzzy matches for UI duplicate warning
    fuzzy_matches = MatchingService.find_fuzzy_matches(
        db=db, shop_id=shop.id, extracted_name=customer.name, threshold=0.75
    )
    # Exclude self from fuzzy list
    fuzzy_matches = [m for m in fuzzy_matches if m.customer_id != customer.id]

    detail = CustomerDetailResponse(
        id=customer.id,
        shop_id=customer.shop_id,
        name=customer.name,
        normalized_name=customer.normalized_name,
        phone=customer.phone,
        address=customer.address,
        notes=customer.notes,
        credit_balance=customer.credit_balance,
        total_credit=customer.total_credit,
        total_payment=customer.total_payment,
        is_active=customer.is_active,
        created_at=customer.created_at,
        updated_at=customer.updated_at,
        transaction_count=len(customer.transactions),
        fuzzy_matches=fuzzy_matches,
    )
    return detail


@router.put("/{customer_id}", response_model=CustomerResponse)
def update_customer(
    customer_id: int,
    data: CustomerUpdate,
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    customer = db.query(Customer).filter(
        Customer.id == customer_id,
        Customer.shop_id == shop.id,
    ).first()

    if not customer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer not found.")

    if data.name:
        customer.name = data.name.strip()
        customer.normalized_name = MatchingService.normalize_name(data.name)
    if data.phone is not None:
        customer.phone = data.phone.strip() if data.phone else None
    if data.address is not None:
        customer.address = data.address.strip() if data.address else None
    if data.notes is not None:
        customer.notes = data.notes.strip() if data.notes else None
    if data.is_active is not None:
        customer.is_active = data.is_active

    db.commit()
    db.refresh(customer)
    return customer


@router.delete("/{customer_id}")
def delete_customer(
    customer_id: int,
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    customer = db.query(Customer).filter(
        Customer.id == customer_id,
        Customer.shop_id == shop.id,
    ).first()

    if not customer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer not found.")

    # Soft delete
    customer.is_active = False
    db.commit()
    return {"message": f"Customer '{customer.name}' archived successfully."}
