from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from backend.database import get_db
from backend.models.shop import Shop
from backend.schemas.shop import ShopResponse, ShopUpdate
from backend.services.auth_service import get_current_shop

router = APIRouter(prefix="/shops", tags=["Shops"])


@router.get("/current", response_model=ShopResponse)
def get_shop(shop: Shop = Depends(get_current_shop)):
    return shop


@router.put("/current", response_model=ShopResponse)
def update_shop(
    data: ShopUpdate,
    shop: Shop = Depends(get_current_shop),
    db: Session = Depends(get_db),
):
    if data.name:
        shop.name = data.name.strip()
    if data.owner_name:
        shop.owner_name = data.owner_name.strip()
    if data.phone:
        shop.phone = data.phone.strip()
    if data.address is not None:
        shop.address = data.address.strip()
    if data.gstin is not None:
        shop.gstin = data.gstin.strip().upper() if data.gstin else None

    db.commit()
    db.refresh(shop)
    return shop
