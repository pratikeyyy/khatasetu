import re
from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
from datetime import datetime


class UserRegister(BaseModel):
    email: EmailStr
    password: str
    owner_name: str
    shop_name: str
    phone: str
    shop_address: Optional[str] = None
    gstin: Optional[str] = None  # Optional GSTIN

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("Password must be at least 6 characters long")
        return v

    @field_validator("gstin")
    @classmethod
    def validate_gstin(cls, v: Optional[str]) -> Optional[str]:
        if not v or not v.strip():
            return None
        v = v.strip().upper()
        # Indian GSTIN regex: 2 state digits, 5 PAN letters, 4 PAN digits, 1 PAN letter, 1 entity digit/letter, 'Z', 1 check digit/letter
        pattern = r"^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$"
        if not re.match(pattern, v):
            raise ValueError("Invalid GSTIN format. Expected format: 22AAAAA0000A1Z5")
        return v


class UserLogin(BaseModel):
    email: EmailStr
    password: str
    remember_me: bool = True


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    shop_id: int
    owner_name: str
    shop_name: str
    email: str


class UserResponse(BaseModel):
    id: int
    email: str
    full_name: str
    phone: Optional[str]
    is_active: bool
    role: str
    created_at: datetime

    class Config:
        from_attributes = True


class ProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None
    shop_name: Optional[str] = None
    shop_address: Optional[str] = None
    gstin: Optional[str] = None

    @field_validator("gstin")
    @classmethod
    def validate_gstin(cls, v: Optional[str]) -> Optional[str]:
        if not v or not v.strip():
            return None
        v = v.strip().upper()
        pattern = r"^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$"
        if not re.match(pattern, v):
            raise ValueError("Invalid GSTIN format. Expected format: 22AAAAA0000A1Z5")
        return v


class PasswordChange(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("New password must be at least 6 characters long")
        return v
