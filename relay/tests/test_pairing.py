from __future__ import annotations

from datetime import timedelta

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.config import Settings
from app.main import create_app
from app.models import PairingInvite, User
from app.pairing import SetupCodePayload, build_setup_code, decode_setup_code
from app.services import create_pairing_invite


def build_client(tmp_path):
    settings = Settings(
        environment="test",
        public_base_url="https://relay.example.test/v1",
        database_url=f"sqlite:///{tmp_path / 'relay-pairing.db'}",
        internal_api_key="test-internal-key",
        pairing_code_ttl_seconds=900,
    )
    app = create_app(settings)
    return TestClient(app)


def pairing_payload(invite_token: str, installation_id: str, display_name: str = "Taylor") -> dict:
    return {
        "inviteToken": invite_token,
        "displayName": display_name,
        "device": {
            "platform": "ios",
            "deviceName": "Taylor's iPhone",
            "appVersion": "1.0.0",
            "buildNumber": "1",
            "bundleId": "com.appfactory.HermesMobile",
            "installationId": installation_id,
            "deviceModel": "iPhone17,2",
            "systemVersion": "26.2",
        },
        "client": {
            "environment": "production",
        },
    }


def create_invite(client: TestClient) -> tuple[PairingInvite, str]:
    with client.app.state.database.session() as db:
        return create_pairing_invite(db, settings=client.app.state.settings)


def test_setup_code_roundtrip_preserves_public_host_and_expiry(tmp_path):
    with build_client(tmp_path) as client:
        invite, invite_token = create_invite(client)
        setup_code = build_setup_code(
            SetupCodePayload(
                relay_url=client.app.state.settings.public_base_url,
                invite_token=invite_token,
                expires_at=invite.expires_at,
            )
        )

        decoded = decode_setup_code(setup_code)

        assert decoded.relay_url == "https://relay.example.test/v1"
        assert decoded.invite_token == invite_token
        assert decoded.expires_at == invite.expires_at


def test_pairing_redeem_returns_bootstrap_data_and_consumes_invite(tmp_path):
    with build_client(tmp_path) as client:
        invite, invite_token = create_invite(client)

        response = client.post(
            "/v1/pairing/redeem",
            json=pairing_payload(
                invite_token=invite_token,
                installation_id="11111111-1111-1111-1111-111111111111",
            ),
        )

        assert response.status_code == 200
        data = response.json()["data"]
        assert data["user"]["displayName"] == "Taylor"
        assert data["deviceRegistered"] is True
        assert data["auth"]["accessToken"]
        assert data["auth"]["refreshToken"]

        with client.app.state.database.session() as db:
            redeemed = db.get(PairingInvite, invite.id)
            assert redeemed is not None
            assert redeemed.redeemed_at is not None
            assert redeemed.redeemed_user_id is not None
            assert redeemed.redeemed_device_id is not None
            assert db.scalar(select(User).where(User.id == redeemed.redeemed_user_id)).display_name == "Taylor"


def test_pairing_redeem_rejects_used_invites(tmp_path):
    with build_client(tmp_path) as client:
        _, invite_token = create_invite(client)
        first_payload = pairing_payload(
            invite_token=invite_token,
            installation_id="22222222-2222-2222-2222-222222222222",
        )

        first_response = client.post("/v1/pairing/redeem", json=first_payload)
        assert first_response.status_code == 200

        second_response = client.post(
            "/v1/pairing/redeem",
            json=pairing_payload(
                invite_token=invite_token,
                installation_id="33333333-3333-3333-3333-333333333333",
            ),
        )
        assert second_response.status_code == 400
        assert second_response.json()["detail"] == "This setup code has already been used."


def test_pairing_redeem_rejects_expired_invites(tmp_path):
    with build_client(tmp_path) as client:
        invite, invite_token = create_invite(client)

        with client.app.state.database.session() as db:
            stored_invite = db.get(PairingInvite, invite.id)
            stored_invite.expires_at = stored_invite.expires_at - timedelta(hours=1)
            db.commit()

        response = client.post(
            "/v1/pairing/redeem",
            json=pairing_payload(
                invite_token=invite_token,
                installation_id="44444444-4444-4444-4444-444444444444",
            ),
        )
        assert response.status_code == 400
        assert response.json()["detail"] == "This setup code has expired."


def test_auth_revoke_invalidates_current_session(tmp_path):
    with build_client(tmp_path) as client:
        _, invite_token = create_invite(client)
        redeem_response = client.post(
            "/v1/pairing/redeem",
            json=pairing_payload(
                invite_token=invite_token,
                installation_id="55555555-5555-5555-5555-555555555555",
            ),
        )
        access_token = redeem_response.json()["data"]["auth"]["accessToken"]

        revoke_response = client.post(
            "/v1/auth/revoke",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        assert revoke_response.status_code == 200
        assert revoke_response.json()["data"]["revoked"] is True

        session_response = client.get(
            "/v1/session",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        assert session_response.status_code == 401


def test_pairing_creates_separate_users_with_isolated_conversations(tmp_path):
    with build_client(tmp_path) as client:
        _, invite_token_one = create_invite(client)
        first_redeem = client.post(
            "/v1/pairing/redeem",
            json=pairing_payload(
                invite_token=invite_token_one,
                installation_id="66666666-6666-6666-6666-666666666666",
                display_name="Alex",
            ),
        )
        first_access_token = first_redeem.json()["data"]["auth"]["accessToken"]
        first_user_id = first_redeem.json()["data"]["user"]["id"]

        message_response = client.post(
            "/v1/messages",
            headers={"Authorization": f"Bearer {first_access_token}"},
            json={"text": "Hello from Alex"},
        )
        assert message_response.status_code == 200

        _, invite_token_two = create_invite(client)
        second_redeem = client.post(
            "/v1/pairing/redeem",
            json=pairing_payload(
                invite_token=invite_token_two,
                installation_id="77777777-7777-7777-7777-777777777777",
                display_name="Blair",
            ),
        )
        second_access_token = second_redeem.json()["data"]["auth"]["accessToken"]
        second_user_id = second_redeem.json()["data"]["user"]["id"]

        assert first_user_id != second_user_id

        first_conversation = client.get(
            "/v1/conversations/current",
            headers={"Authorization": f"Bearer {first_access_token}"},
        )
        second_conversation = client.get(
            "/v1/conversations/current",
            headers={"Authorization": f"Bearer {second_access_token}"},
        )

        assert len(first_conversation.json()["data"]["conversation"]["messages"]) == 2
        assert second_conversation.json()["data"]["conversation"]["messages"] == []
