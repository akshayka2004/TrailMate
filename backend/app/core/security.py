from datetime import datetime, timedelta, timezone
from typing import Any, Literal

from jose import jwt
from passlib.context import CryptContext

from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def _create_token(
    user_id: int,
    token_type: Literal["access", "refresh"],
    expires_delta: timedelta,
    extra: dict[str, Any] | None = None,
) -> str:
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "type": token_type,
        "exp": datetime.now(timezone.utc) + expires_delta,
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_access_token(user_id: int, role: str) -> str:
    return _create_token(
        user_id,
        "access",
        timedelta(minutes=settings.access_token_expire_minutes),
        {"role": role},
    )


def create_refresh_token(user_id: int) -> str:
    return _create_token(
        user_id,
        "refresh",
        timedelta(days=settings.refresh_token_expire_days),
    )


def decode_token(token: str) -> dict[str, Any]:
    """Decode and validate a JWT. Raises jose.JWTError on any problem."""
    return jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
