from __future__ import annotations

from threading import Thread

from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.pairing import decode_host_setup_code


def build_client(tmp_path):
    settings = Settings(
        environment="test",
        public_base_url="https://relay.example.test/v1",
        database_url=f"sqlite:///{tmp_path / 'relay-hosts.db'}",
        internal_api_key="test-internal-key",
        pairing_code_ttl_seconds=900,
        host_enrollment_code_ttl_seconds=900,
        hermes_adapter="connector",
        connector_sync_wait_seconds=2,
        connector_job_lease_seconds=30,
        connector_heartbeat_timeout_seconds=5,
        connector_idle_poll_interval_seconds=0.1,
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

def create_paired_user(client: TestClient, installation_id: str = "11111111-1111-1111-1111-111111111111") -> tuple[str, str]:
    from app.services import create_pairing_invite

    with client.app.state.database.session() as db:
        _, invite_token = create_pairing_invite(db, settings=client.app.state.settings)

    response = client.post(
        "/v1/pairing/redeem",
        json=pairing_payload(invite_token=invite_token, installation_id=installation_id),
    )
    assert response.status_code == 200
    data = response.json()["data"]
    return data["auth"]["accessToken"], data["user"]["id"]


def create_host_code(client: TestClient, access_token: str) -> str:
    response = client.post(
        "/v1/hosts/enrollment-codes",
        headers={"Authorization": f"Bearer {access_token}"},
        json={},
    )
    assert response.status_code == 200
    return response.json()["data"]["setupCode"]


def redeem_host(client: TestClient, host_code: str) -> dict:
    payload = decode_host_setup_code(host_code)
    response = client.post(
        "/v1/hosts/redeem",
        json={
            "enrollmentToken": payload.enrollment_token,
            "displayName": "Home Mac mini",
            "connector": {
                "platform": "macos",
                "hostname": "dylans-mac-mini",
                "connectorVersion": "0.1.0",
                "hermesCommand": "/Users/dylan/.local/bin/hermes",
                "hermesVersion": "hermes 1.2.3",
            },
        },
    )
    assert response.status_code == 200
    return response.json()["data"]


def test_host_enrollment_code_and_redeem_create_relay_host(tmp_path):
    with build_client(tmp_path) as client:
        access_token, _ = create_paired_user(client)
        host_code = create_host_code(client, access_token)
        data = redeem_host(client, host_code)

        assert data["host"]["id"]
        assert data["connectorCredential"]
        assert data["webSocketURL"] == "wss://relay.example.test/v1/hosts/ws"

        current_host = client.get(
            "/v1/hosts/current",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        assert current_host.status_code == 200
        host = current_host.json()["data"]["host"]
        assert host["displayName"] == "Home Mac mini"
        assert host["isOnline"] is False


def test_messages_return_pending_when_host_is_offline(tmp_path):
    with build_client(tmp_path) as client:
        access_token, _ = create_paired_user(client)

        message_response = client.post(
            "/v1/messages",
            headers={"Authorization": f"Bearer {access_token}"},
            json={"text": "Hello while offline"},
        )
        assert message_response.status_code == 202
        data = message_response.json()["data"]
        assert data["replyState"] == "pending"
        assert data["message"] is None if "message" in data else True
        assert data["conversation"]["messages"][0]["deliveryStatus"] == "pending"


def test_connected_host_gets_job_and_preserves_session_resume(tmp_path):
    with build_client(tmp_path) as client:
        access_token, _ = create_paired_user(client)
        host_code = create_host_code(client, access_token)
        host_data = redeem_host(client, host_code)
        connector_credential = host_data["connectorCredential"]

        with client.websocket_connect(
            "/v1/hosts/ws",
            headers={"Authorization": f"Bearer {connector_credential}"},
        ) as websocket:
            websocket.send_json(
                {
                    "type": "hello",
                    "connector": {
                        "platform": "macos",
                        "hostname": "dylans-mac-mini",
                        "connectorVersion": "0.1.0",
                        "hermesCommand": "/Users/dylan/.local/bin/hermes",
                        "hermesVersion": "hermes 1.2.3",
                        "displayName": "Home Mac mini",
                    },
                }
            )
            ready = websocket.receive_json()
            assert ready["type"] == "ready"

            first_response: dict = {}

            def send_first_message() -> None:
                first_response["payload"] = client.post(
                    "/v1/messages",
                    headers={"Authorization": f"Bearer {access_token}"},
                    json={"text": "Hello from phone"},
                )

            thread = Thread(target=send_first_message)
            thread.start()
            first_job = websocket.receive_json()
            assert first_job["type"] == "job.execute"
            assert first_job["job"]["sessionId"] is None

            websocket.send_json(
                {
                    "type": "job.result",
                    "jobId": first_job["job"]["id"],
                    "text": "First connector reply",
                    "sessionId": "session-123",
                }
            )
            thread.join(timeout=5)
            assert first_response["payload"].status_code == 200
            assert first_response["payload"].json()["data"]["replyState"] == "delivered"

            second_response: dict = {}

            def send_second_message() -> None:
                second_response["payload"] = client.post(
                    "/v1/messages",
                    headers={"Authorization": f"Bearer {access_token}"},
                    json={"text": "Follow up"},
                )

            second_thread = Thread(target=send_second_message)
            second_thread.start()
            second_job = websocket.receive_json()
            assert second_job["job"]["sessionId"] == "session-123"
            websocket.send_json(
                {
                    "type": "job.result",
                    "jobId": second_job["job"]["id"],
                    "text": "Second connector reply",
                    "sessionId": "session-123",
                }
            )
            second_thread.join(timeout=5)
            assert second_response["payload"].status_code == 200
            messages = second_response["payload"].json()["data"]["conversation"]["messages"]
            assert messages[-1]["text"] == "Second connector reply"


def test_replacing_host_rotates_connector_credential_and_updates_current_host(tmp_path):
    with build_client(tmp_path) as client:
        access_token, _ = create_paired_user(client)
        first_host = redeem_host(client, create_host_code(client, access_token))
        second_host = redeem_host(client, create_host_code(client, access_token))

        assert first_host["connectorCredential"] != second_host["connectorCredential"]
        current_host = client.get(
            "/v1/hosts/current",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        assert current_host.status_code == 200
        assert current_host.json()["data"]["host"]["id"] == second_host["host"]["id"]
