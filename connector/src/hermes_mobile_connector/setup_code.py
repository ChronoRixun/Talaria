from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
import base64
import json


HOST_SETUP_CODE_PREFIX = "HC1:"


@dataclass(frozen=True)
class HostSetupCodePayload:
    relay_url: str
    enrollment_token: str
    expires_at: datetime | None = None


def decode_host_setup_code(code: str) -> HostSetupCodePayload:
    if not code.startswith(HOST_SETUP_CODE_PREFIX):
        raise ValueError("Unsupported setup code version.")

    encoded = code[len(HOST_SETUP_CODE_PREFIX) :]
    padding = "=" * (-len(encoded) % 4)
    try:
        decoded = base64.urlsafe_b64decode(f"{encoded}{padding}".encode("utf-8")).decode("utf-8")
        payload = json.loads(decoded)
    except (ValueError, json.JSONDecodeError, UnicodeDecodeError) as error:
        raise ValueError("Invalid setup code.") from error

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
