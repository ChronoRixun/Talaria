from __future__ import annotations

import hashlib
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from fastapi import Depends, Header, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from .config import Settings
from .database import Database
from .models import AuthSession, Device, User


bearer_scheme = HTTPBearer(auto_error=False)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def normalize_datetime(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def generate_token() -> str:
    return secrets.token_urlsafe(32)


@dataclass
class AuthContext:
    auth_session: AuthSession
    device: Device
    user: User


def issue_tokens(settings: Settings) -> tuple[str, str, datetime, datetime]:
    access_token = generate_token()
    refresh_token = generate_token()
    access_expires_at = utcnow() + timedelta(seconds=settings.access_token_ttl_seconds)
    refresh_expires_at = utcnow() + timedelta(seconds=settings.refresh_token_ttl_seconds)
    return access_token, refresh_token, access_expires_at, refresh_expires_at


def get_database(request: Request) -> Database:
    return request.app.state.database


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


def get_db(request: Request):
    database = get_database(request)
    with database.session() as db:
        yield db


def require_internal_key(
    request: Request,
    x_relay_internal_key: str | None = Header(default=None, alias="X-Relay-Internal-Key"),
) -> None:
    settings = get_settings(request)
    if x_relay_internal_key != settings.internal_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid internal API key.")


def get_auth_context(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> AuthContext:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token.")

    token_hash = hash_token(credentials.credentials)
    auth_session = db.scalar(
        select(AuthSession).where(
            AuthSession.access_token_hash == token_hash,
            AuthSession.revoked_at.is_(None),
        )
    )

    if auth_session is None or normalize_datetime(auth_session.access_expires_at) < utcnow():
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Expired or invalid access token.")

    device = db.get(Device, auth_session.device_id)
    user = db.get(User, auth_session.user_id)

    if device is None or user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid auth context.")

    return AuthContext(auth_session=auth_session, device=device, user=user)
