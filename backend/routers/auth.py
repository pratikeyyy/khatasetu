from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from backend.database import get_db
from backend.models.user import User
from backend.models.shop import Shop
from backend.schemas.user import (
    UserRegister,
    UserLogin,
    Token,
    UserResponse,
    ProfileUpdate,
    PasswordChange,
)
from backend.services.auth_service import (
    verify_password,
    get_password_hash,
    create_access_token,
    get_current_user,
    get_current_shop,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
def register(data: UserRegister, db: Session = Depends(get_db)):
    # 1. Check if user already exists
    existing = db.query(User).filter(User.email == data.email.lower().strip()).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="An account with this email already exists.",
        )

    # 2. Create User
    user = User(
        email=data.email.lower().strip(),
        password_hash=get_password_hash(data.password),
        full_name=data.owner_name.strip(),
        phone=data.phone.strip(),
        is_active=True,
    )
    db.add(user)
    db.flush()

    # 3. Create Shop
    shop = Shop(
        owner_id=user.id,
        name=data.shop_name.strip(),
        owner_name=data.owner_name.strip(),
        phone=data.phone.strip(),
        address=data.shop_address.strip() if data.shop_address else None,
        gstin=data.gstin.strip().upper() if data.gstin else None,
    )
    db.add(shop)
    db.commit()
    db.refresh(user)
    db.refresh(shop)

    # 4. Generate JWT
    token = create_access_token({"sub": str(user.id), "shop_id": shop.id, "email": user.email})
    return Token(
        access_token=token,
        token_type="bearer",
        user_id=user.id,
        shop_id=shop.id,
        owner_name=user.full_name,
        shop_name=shop.name,
        email=user.email,
    )


@router.post("/login", response_model=Token)
def login(data: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email.lower().strip()).first()
    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password.",
        )
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is deactivated.")

    shop = db.query(Shop).filter(Shop.owner_id == user.id).first()
    shop_id = shop.id if shop else 0
    shop_name = shop.name if shop else "Kirana Store"

    token = create_access_token({"sub": str(user.id), "shop_id": shop_id, "email": user.email})
    return Token(
        access_token=token,
        token_type="bearer",
        user_id=user.id,
        shop_id=shop_id,
        owner_name=user.full_name,
        shop_name=shop_name,
        email=user.email,
    )


@router.get("/me")
def get_me(user: User = Depends(get_current_user), shop: Shop = Depends(get_current_shop)):
    return {
        "user": {
            "id": user.id,
            "email": user.email,
            "full_name": user.full_name,
            "phone": user.phone,
            "role": user.role,
        },
        "shop": {
            "id": shop.id,
            "name": shop.name,
            "owner_name": shop.owner_name,
            "phone": shop.phone,
            "address": shop.address,
            "gstin": shop.gstin,
            "currency": shop.currency,
            "currency_symbol": shop.currency_symbol,
        },
    }


@router.put("/profile")
def update_profile(
    data: ProfileUpdate,
    user: User = Depends(get_current_user),
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    if data.full_name:
        user.full_name = data.full_name.strip()
    if data.phone:
        user.phone = data.phone.strip()
        shop.phone = data.phone.strip()
    if data.shop_name:
        shop.name = data.shop_name.strip()
    if data.shop_address is not None:
        shop.address = data.shop_address.strip()
    if data.gstin is not None:
        shop.gstin = data.gstin.strip().upper() if data.gstin else None

    db.commit()
    return {"message": "Profile updated successfully"}


@router.post("/change-password")
def change_password(
    data: PasswordChange,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not verify_password(data.current_password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Incorrect current password.")

    user.password_hash = get_password_hash(data.new_password)
    db.commit()
    return {"message": "Password changed successfully."}
