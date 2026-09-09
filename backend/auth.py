from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from config import settings
import random
import string

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    """Hash a password"""
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash"""
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create JWT access token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt

def decode_access_token(token: str) -> Optional[dict]:
    """Decode JWT access token"""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload
    except JWTError:
        return None

def generate_verification_code() -> str:
    """Generate a random verification code"""
    return ''.join(random.choices(string.digits, k=settings.VERIFICATION_CODE_LENGTH))

def get_verification_expiry() -> datetime:
    """Get verification code expiry time"""
    return datetime.now() + timedelta(minutes=settings.VERIFICATION_CODE_EXPIRE_MINUTES)

def format_phone_number(phone: str) -> str:
    """Format phone number to standard format"""
    # Remove all non-digit characters
    digits = ''.join(filter(str.isdigit, phone))
    
    # Add + if not present
    if not phone.startswith('+'):
        return f"+{digits}"
    return phone
