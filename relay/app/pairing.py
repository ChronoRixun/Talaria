from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
import base64
import json


APP_SETUP_CODE_PREFIX = "HM1:"
HOST_SETUP_CODE_PREFIX = "HC1:"


@dataclass(frozen=True)
class SetupCodePayload:
    relay_url: str
    invite_token: str
    expires_at: datetime | None = None


@dataclass(frozen=True)
class HostSetupCodePayload:
    relay_url: str
    enrollment_token: str
    expires_at: datetime | None = None


def _encode_payload(body: dict) -> str:
    return base64.urlsafe_b64encode(
        json.dumps(body, separators=(",", ":"), sort_keys=True).encode("utf-8")
    ).decode("utf-8").rstrip("=")


def _decode_payload(code: str, prefix: str) -> dict:
    if not code.startswith(prefix):
        raise ValueError("Unsupported setup code version.")

    encoded = code[len(prefix) :]
    padding = "=" * (-len(encoded) % 4)
    try:
        decoded = base64.urlsafe_b64decode(f"{encoded}{padding}".encode("utf-8")).decode("utf-8")
        return json.loads(decoded)
    except (ValueError, json.JSONDecodeError, UnicodeDecodeError) as error:
        raise ValueError("Invalid setup code.") from error


def build_setup_code(payload: SetupCodePayload) -> str:
    body = {
        "relay_url": payload.relay_url,
        "invite_token": payload.invite_token,
        "expires_at": payload.expires_at.isoformat() if payload.expires_at else None,
    }
    return f"{APP_SETUP_CODE_PREFIX}{_encode_payload(body)}"


def decode_setup_code(code: str) -> SetupCodePayload:
    payload = _decode_payload(code, APP_SETUP_CODE_PREFIX)
    relay_url = payload.get("relay_url")
    invite_token = payload.get("invite_token")
    expires_at = payload.get("expires_at")

    if not relay_url or not invite_token:
        raise ValueError("Invalid setup code.")

    return SetupCodePayload(
        relay_url=relay_url,
        invite_token=invite_token,
        expires_at=datetime.fromisoformat(expires_at) if expires_at else None,
    )


def build_host_setup_code(payload: HostSetupCodePayload) -> str:
    body = {
        "relay_url": payload.relay_url,
        "enrollment_token": payload.enrollment_token,
        "expires_at": payload.expires_at.isoformat() if payload.expires_at else None,
    }
    return f"{HOST_SETUP_CODE_PREFIX}{_encode_payload(body)}"


def decode_host_setup_code(code: str) -> HostSetupCodePayload:
    payload = _decode_payload(code, HOST_SETUP_CODE_PREFIX)
    relay_url = payload.get("relay_url")
    enrollment_token = payload.get("enrollment_token")
    expires_at = payload.get("expires_at")

    if not relay_url or not enrollment_token:
        raise ValueError("Invalid setup code.")

    return HostSetupCodePayload(
        relay_url=relay_url,
        enrollment_token=enrollment_token,
        expires_at=datetime.fromisoformat(expires_at) if expires_at else None,
    )
