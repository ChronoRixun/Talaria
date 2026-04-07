"""APNs (Apple Push Notification service) client for sending silent push notifications.

Uses HTTP/2 via httpx with JWT bearer token authentication.
Requires a .p8 key file from Apple Developer Portal.

Environment variables:
    APNS_KEY_PATH       — path to the .p8 private key file
    APNS_KEY_ID         — 10-char key identifier from Apple
    APNS_TEAM_ID        — 10-char team identifier from Apple
    APNS_BUNDLE_ID      — app bundle identifier (default: io.hermesmobile.HermesMobile)
    APNS_ENVIRONMENT    — "development" or "production" (default: development)
"""

from __future__ import annotations

import json
import logging
import time
from pathlib import Path
import tempfile

import httpx

from .config import Settings

logger = logging.getLogger("hermes.relay.apns")

# APNs endpoints
APNS_DEVELOPMENT_URL = "https://api.development.push.apple.com"
APNS_PRODUCTION_URL = "https://api.push.apple.com"


class APNsClient:
    """Sends push notifications to Apple's APNs service."""

    def __init__(
        self,
        *,
        key_path: str,
        key_id: str,
        team_id: str,
        bundle_id: str = "io.hermesmobile.HermesMobile",
        environment: str = "development",
    ):
        self.key_id = key_id
        self.team_id = team_id
        self.bundle_id = bundle_id
        self.environment = environment
        self.base_url = APNS_PRODUCTION_URL if environment == "production" else APNS_DEVELOPMENT_URL

        key_file = Path(key_path)
        if not key_file.exists():
            raise FileNotFoundError(f"APNs key file not found: {key_path}")
        self._private_key = key_file.read_text().strip()

        # Cache the JWT token (valid for up to 60 minutes)
        self._token: str | None = None
        self._token_issued_at: float = 0

        self._client: httpx.AsyncClient | None = None

    async def _get_client(self) -> httpx.AsyncClient:
        if self._client is None or self._client.is_closed:
            self._client = httpx.AsyncClient(http2=True, timeout=30.0)
        return self._client

    def _build_jwt(self) -> str:
        """Build a JWT token for APNs authentication.

        Uses the ES256 algorithm with the .p8 private key.
        Tokens are valid for up to 60 minutes; we refresh at 50 minutes.
        """
        import jwt  # PyJWT — added as dependency

        now = int(time.time())
        payload = {
            "iss": self.team_id,
            "iat": now,
        }
        headers = {
            "alg": "ES256",
            "kid": self.key_id,
        }
        return jwt.encode(payload, self._private_key, algorithm="ES256", headers=headers)

    def _get_token(self) -> str:
        """Get a cached or fresh JWT token."""
        now = time.time()
        # Refresh if older than 50 minutes (APNs allows up to 60)
        if self._token is None or (now - self._token_issued_at) > 3000:
            self._token = self._build_jwt()
            self._token_issued_at = now
        return self._token

    async def send_silent_push(self, device_token: str) -> bool:
        """Send a silent (content-available) push notification to wake the app.

        Returns True if APNs accepted the notification, False otherwise.
        """
        url = f"{self.base_url}/3/device/{device_token}"
        token = self._get_token()

        headers = {
            "authorization": f"bearer {token}",
            "apns-topic": self.bundle_id,
            "apns-push-type": "background",
            "apns-priority": "5",  # Low priority for background pushes
        }

        # Minimal payload — content-available: 1 tells iOS to wake the app
        payload = {
            "aps": {
                "content-available": 1,
            },
        }

        try:
            client = await self._get_client()
            response = await client.post(url, headers=headers, json=payload)

            if response.status_code == 200:
                logger.info(f"APNs push sent to {device_token[:8]}...")
                return True
            else:
                body = response.text
                logger.warning(
                    f"APNs push failed: {response.status_code} — {body}"
                )
                # 410 Gone means the token is no longer valid
                if response.status_code == 410:
                    logger.info(f"APNs token {device_token[:8]}... is no longer valid")
                return False

        except Exception as e:
            logger.error(f"APNs push error: {e}")
            return False

    async def send_alert_push(
        self,
        device_token: str,
        *,
        title: str,
        body: str,
        category: str | None = None,
    ) -> bool:
        """Send a visible alert push notification.

        Returns True if APNs accepted the notification.
        """
        url = f"{self.base_url}/3/device/{device_token}"
        token = self._get_token()

        headers = {
            "authorization": f"bearer {token}",
            "apns-topic": self.bundle_id,
            "apns-push-type": "alert",
            "apns-priority": "10",  # High priority for alerts
        }

        payload: dict = {
            "aps": {
                "alert": {
                    "title": title,
                    "body": body,
                },
                "sound": "default",
            },
        }
        if category:
            payload["aps"]["category"] = category

        try:
            client = await self._get_client()
            response = await client.post(url, headers=headers, json=payload)

            if response.status_code == 200:
                logger.info(f"APNs alert sent to {device_token[:8]}...")
                return True
            else:
                logger.warning(f"APNs alert failed: {response.status_code} — {response.text}")
                return False

        except Exception as e:
            logger.error(f"APNs alert error: {e}")
            return False

    async def close(self):
        if self._client and not self._client.is_closed:
            await self._client.aclose()


def create_apns_client(settings: Settings) -> APNsClient | None:
    """Create an APNs client from typed settings, or None if not configured."""
    if not all([settings.apns_key_id, settings.apns_team_id]):
        logger.info("APNs not configured (missing APNS_KEY_ID or APNS_TEAM_ID)")
        return None

    key_path = settings.apns_key_path
    key_contents = settings.apns_key_contents

    if not key_path and not key_contents:
        logger.info("APNs not configured (missing APNS_KEY_PATH or APNS_KEY_CONTENTS)")
        return None

    # If key contents provided inline, write to a temp file
    if not key_path and key_contents:
        tmp = tempfile.NamedTemporaryFile(mode="w", suffix=".p8", delete=False)
        tmp.write(key_contents)
        tmp.close()
        key_path = tmp.name
        logger.info("APNs key loaded from APNS_KEY_CONTENTS env var")

    try:
        client = APNsClient(
            key_path=key_path,
            key_id=settings.apns_key_id,
            team_id=settings.apns_team_id,
            bundle_id=settings.apns_bundle_id,
            environment=settings.apns_environment,
        )
        logger.info(
            "APNs client initialized (%s, bundle: %s)",
            settings.apns_environment,
            settings.apns_bundle_id,
        )
        return client
    except FileNotFoundError as e:
        logger.warning(f"APNs key file not found: {e}")
        return None
    except Exception as e:
        logger.error(f"APNs client initialization failed: {e}")
        return None
