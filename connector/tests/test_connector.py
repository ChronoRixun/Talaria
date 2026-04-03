from __future__ import annotations

import asyncio
import base64
import json

from hermes_mobile_connector.client import HermesMobileConnector
from hermes_mobile_connector.hermes_runner import ConnectorHermesSettings, HermesCLIExecutor
from hermes_mobile_connector.mcp_registration import (
    MCPRegistrationStatus,
    native_mcp_readiness_message,
    register_native_mcp_server,
)
from hermes_mobile_connector.setup_code import decode_host_setup_code
from hermes_mobile_connector.runtime_adapter import HermesRuntimeAdapter, RuntimeConversationMessage
from hermes_mobile_connector.state import (
    ConnectorSecrets,
    ConnectorState,
    ConnectorStateStore,
    RealtimeTalkConfig,
    VoiceContextSnapshot,
)


def make_executor() -> HermesCLIExecutor:
    return HermesCLIExecutor(
        ConnectorHermesSettings(
            hermes_command="hermes",
            hermes_workdir=None,
            hermes_provider=None,
            hermes_model=None,
            hermes_toolsets=None,
            hermes_source="tool",
            hermes_history_limit=20,
        )
    )


def test_decode_host_setup_code_roundtrip():
    payload = {
        "relay_url": "https://relay.example.com/v1",
        "enrollment_token": "token-123",
        "expires_at": "2026-03-31T16:00:00+00:00",
    }
    encoded = base64.urlsafe_b64encode(
        json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
    ).decode("utf-8").rstrip("=")
    code = f"HC1:{encoded}"
    decoded = decode_host_setup_code(code)
    assert decoded.relay_url == "https://relay.example.com/v1"
    assert decoded.enrollment_token == "token-123"


def test_state_store_persists_with_restricted_permissions(tmp_path):
    store = ConnectorStateStore(state_dir=tmp_path / "connector-state")
    state = ConnectorState(
        relay_url="https://relay.example.com/v1",
        web_socket_url="wss://relay.example.com/v1/hosts/ws",
        user_id="user-123",
        host_id="host-123",
        connector_credential="secret",

        connector_display_name="Home Mac mini",
        enrolled_at="2026-03-31T16:00:00+00:00",
    )
    store.save(state)
    loaded = store.load()
    assert loaded.host_id == "host-123"
    assert loaded.user_id == "user-123"
    assert store.state_path.exists()


def test_setup_creates_connector_state(monkeypatch, tmp_path):
    store = ConnectorStateStore(state_dir=tmp_path / "connector-setup")
    connector = HermesMobileConnector(state_store=store, executor=make_executor())
    monkeypatch.setattr(connector.executor, "detect_version", lambda: "Hermes 1.2.3")
    monkeypatch.setattr(
        "hermes_mobile_connector.client.register_native_mcp_server",
        lambda state_dir: MCPRegistrationStatus(
            server_name="hermes_mobile",
            hermes_home=tmp_path / ".hermes",
            config_path=tmp_path / ".hermes" / "config.yaml",
            command_path="/tmp/hermes-mobile-mcp",
            registered=True,
        ),
    )
    monkeypatch.setattr("hermes_mobile_connector.client.validate_native_mcp_server", lambda hermes_command, server_name: None)
    monkeypatch.setattr("hermes_mobile_connector.client.validate_native_mcp_tools", lambda server_name: None)

    class FakeResponse:
        def raise_for_status(self) -> None:
            return None

        def json(self) -> dict:
            return {
                "data": {
                    "user": {"id": "user-123", "displayName": "Taylor"},
                    "host": {"id": "host-123", "userId": "user-123"},
                    "connectorCredential": "secret-token",
                    "webSocketURL": "wss://relay.example.com/v1/hosts/ws",
                    "relayURL": "https://relay.example.com/v1",
                }
            }

    def fake_post(url, json=None, timeout=None, headers=None):  # noqa: ANN001
        assert url == "https://relay.example.com/v1/connector/setup"
        assert "connector" in json
        return FakeResponse()

    monkeypatch.setattr("hermes_mobile_connector.client.httpx.post", fake_post)

    state = connector.setup(relay_url="https://relay.example.com/v1")

    assert state.user_id == "user-123"
    assert state.host_id == "host-123"
    assert state.mcp_configured is True
    assert state.mcp_command_path == "/tmp/hermes-mobile-mcp"
    assert state.mcp_last_test_error is None


def test_setup_can_skip_native_mcp_configuration(monkeypatch, tmp_path):
    store = ConnectorStateStore(state_dir=tmp_path / "connector-setup-skip")
    connector = HermesMobileConnector(state_store=store, executor=make_executor())
    monkeypatch.setattr(connector.executor, "detect_version", lambda: "Hermes 1.2.3")

    class FakeResponse:
        def raise_for_status(self) -> None:
            return None

        def json(self) -> dict:
            return {
                "data": {
                    "user": {"id": "user-123", "displayName": "Taylor"},
                    "host": {"id": "host-123", "userId": "user-123"},
                    "connectorCredential": "secret-token",
                    "webSocketURL": "wss://relay.example.com/v1/hosts/ws",
                    "relayURL": "https://relay.example.com/v1",
                }
            }

    def fake_post(url, json=None, timeout=None, headers=None):  # noqa: ANN001
        assert url == "https://relay.example.com/v1/connector/setup"
        return FakeResponse()

    monkeypatch.setattr("hermes_mobile_connector.client.httpx.post", fake_post)
    monkeypatch.setattr(
        "hermes_mobile_connector.client.register_native_mcp_server",
        lambda state_dir: (_ for _ in ()).throw(AssertionError("register_native_mcp_server should not be called")),
    )

    state = connector.setup(relay_url="https://relay.example.com/v1", configure_mcp=False)

    assert state.user_id == "user-123"
    assert state.host_id == "host-123"
    assert state.mcp_configured is False
    assert state.mcp_registered_at is None
    assert state.mcp_last_test_error is None


def test_configure_mcp_updates_existing_connector_state(monkeypatch, tmp_path):
    store = ConnectorStateStore(state_dir=tmp_path / "connector-configure-mcp")
    store.save(
        ConnectorState(
            relay_url="https://relay.example.com/v1",
            web_socket_url="wss://relay.example.com/v1/hosts/ws",
            user_id="user-123",
            host_id="host-123",
            connector_credential="secret-token",
        )
    )
    connector = HermesMobileConnector(state_store=store, executor=make_executor())
    monkeypatch.setattr(connector.executor, "detect_version", lambda: "Hermes 1.2.3")
    monkeypatch.setattr(
        "hermes_mobile_connector.client.register_native_mcp_server",
        lambda state_dir: MCPRegistrationStatus(
            server_name="hermes_mobile",
            hermes_home=tmp_path / ".hermes",
            config_path=tmp_path / ".hermes" / "config.yaml",
            command_path="/tmp/hermes-mobile-mcp",
            registered=True,
        ),
    )
    monkeypatch.setattr("hermes_mobile_connector.client.validate_native_mcp_server", lambda hermes_command, server_name: None)
    monkeypatch.setattr("hermes_mobile_connector.client.validate_native_mcp_tools", lambda server_name: None)

    state = connector.configure_mcp()

    assert state.host_id == "host-123"
    assert state.mcp_configured is True
    assert state.mcp_command_path == "/tmp/hermes-mobile-mcp"
    assert state.mcp_registered_at is not None
    assert state.mcp_last_test_error is None


def test_pair_phone_uses_stored_connector_credential(monkeypatch, tmp_path):
    store = ConnectorStateStore(state_dir=tmp_path / "connector-pair")
    store.save(
        ConnectorState(
            relay_url="https://relay.example.com/v1",
            web_socket_url="wss://relay.example.com/v1/hosts/ws",
            user_id="user-123",
            host_id="host-123",
            connector_credential="secret-token",
    
            connector_display_name="Home Mac mini",
        )
    )
    connector = HermesMobileConnector(state_store=store, executor=make_executor())

    class FakeResponse:
        def raise_for_status(self) -> None:
            return None

        def json(self) -> dict:
            return {
                "data": {
                    "code": "ABCDEFGH",
                    "displayCode": "ABCD-EFGH",
                    "expiresAt": "2026-03-31T16:00:00+00:00",
                }
            }

    def fake_post(url, json=None, timeout=None, headers=None):  # noqa: ANN001
        assert url == "https://relay.example.com/v1/connector/phone-pairing-codes"
        assert headers == {"Authorization": "Bearer secret-token"}
        assert json is None
        return FakeResponse()

    monkeypatch.setattr("hermes_mobile_connector.client.httpx.post", fake_post)

    pairing = connector.create_phone_pairing_code()
    assert pairing.code == "ABCDEFGH"
    assert pairing.display_code == "ABCD-EFGH"


def test_configure_realtime_stores_api_key_in_secrets_only(monkeypatch, tmp_path):
    store = ConnectorStateStore(state_dir=tmp_path / "connector-realtime")
    store.save(
        ConnectorState(
            relay_url="https://relay.example.com/v1",
            web_socket_url="wss://relay.example.com/v1/hosts/ws",
            user_id="user-123",
            host_id="host-123",
            connector_credential="secret-token",
        )
    )
    connector = HermesMobileConnector(state_store=store, executor=make_executor())

    monkeypatch.setattr(connector, "refresh_voice_context", lambda *, state=None: state or store.load())
    monkeypatch.setattr(
        connector,
        "_create_openai_realtime_session",
        lambda **kwargs: (
            {
                "id": "sess_123",
                "type": "realtime",
                "client_secret": {
                    "value": "ephemeral-secret",
                    "expires_at": 1_775_001_600,
                },
            },
            "gpt-realtime-1.5",
        ),
    )

    state = connector.configure_realtime(api_key="sk-test-realtime")

    assert store.load_secrets().openai_api_key == "sk-test-realtime"
    assert "sk-test-realtime" not in store.state_path.read_text(encoding="utf-8")
    assert "sk-test-realtime" in store.secrets_path.read_text(encoding="utf-8")
    assert state.realtime_talk is not None
    assert state.realtime_talk.enabled is True
    assert state.realtime_talk.last_selected_model == "gpt-realtime-1.5"
    assert state.realtime_talk.last_validation_error is None


def test_configure_realtime_clear_removes_api_key_and_disables_talk(tmp_path):
    store = ConnectorStateStore(state_dir=tmp_path / "connector-realtime-clear")
    store.save(
        ConnectorState(
            relay_url="https://relay.example.com/v1",
            web_socket_url="wss://relay.example.com/v1/hosts/ws",
            user_id="user-123",
            host_id="host-123",
            connector_credential="secret-token",
            realtime_talk=RealtimeTalkConfig(enabled=True),
        )
    )
    store.save_secrets(ConnectorSecrets(openai_api_key="sk-test-realtime"))
    connector = HermesMobileConnector(state_store=store, executor=make_executor())

    state = connector.configure_realtime(clear=True)

    assert store.load_secrets().openai_api_key is None
    assert state.realtime_talk is not None
    assert state.realtime_talk.enabled is False
    assert state.voice_context_snapshot is None


def test_realtime_session_creation_falls_back_to_secondary_model(monkeypatch, tmp_path):
    connector = HermesMobileConnector(state_store=ConnectorStateStore(state_dir=tmp_path / "connector-realtime-fallback"), executor=make_executor())
    attempted_models: list[str] = []
    captured_sessions: list[dict] = []

    class FakeResponse:
        def __init__(self, status_code: int, payload: dict) -> None:
            self.status_code = status_code
            self._payload = payload
            self.text = json.dumps(payload)

        def json(self) -> dict:
            return self._payload

    def fake_post(url, headers=None, json=None, timeout=None):  # noqa: ANN001
        attempted_models.append(json["session"]["model"])
        captured_sessions.append(json["session"])
        if len(attempted_models) == 1:
            return FakeResponse(400, {"error": {"message": "Model not available."}})
        return FakeResponse(
            200,
            {
                "id": "sess_456",
                "type": "realtime",
                "model": "gpt-realtime",
                "client_secret": {
                    "value": "ephemeral-secret",
                    "expires_at": 1_775_001_600,
                },
            },
        )

    monkeypatch.setattr("hermes_mobile_connector.client.httpx.post", fake_post)

    payload, selected_model = connector._create_openai_realtime_session(  # noqa: SLF001
        api_key="sk-test-realtime",
        config=RealtimeTalkConfig(preferred_models=["gpt-realtime-1.5", "gpt-realtime"]),
        instructions="Say hello.",
        relay_mcp_url=None,
    )

    assert attempted_models == ["gpt-realtime-1.5", "gpt-realtime"]
    assert captured_sessions[0]["audio"]["output"]["voice"] == "verse"
    assert "voice" not in captured_sessions[0]
    assert "modalities" not in captured_sessions[0]
    assert selected_model == "gpt-realtime"
    assert payload["client_secret"]["value"] == "ephemeral-secret"


def test_talk_session_create_normalizes_client_secret_payload(monkeypatch, tmp_path):
    store = ConnectorStateStore(state_dir=tmp_path / "connector-realtime-session")
    store.save(
        ConnectorState(
            relay_url="https://relay.example.com/v1",
            web_socket_url="wss://relay.example.com/v1/hosts/ws",
            user_id="user-123",
            host_id="host-123",
            connector_credential="secret-token",
            realtime_talk=RealtimeTalkConfig(enabled=True, last_validation_error=None),
            voice_context_snapshot=VoiceContextSnapshot(
                system_prompt="System prompt",
                memory_summary="Memory",
                user_summary="User",
                sensor_summary="Sensors",
                readiness_summary="Ready",
                updated_at="2026-04-01T12:00:00+00:00",
            ),
        )
    )
    store.save_secrets(ConnectorSecrets(openai_api_key="sk-test-realtime"))
    connector = HermesMobileConnector(state_store=store, executor=make_executor())

    monkeypatch.setattr(connector, "refresh_voice_context", lambda *, state=None: state or store.load())
    monkeypatch.setattr(
        connector,
        "_create_openai_realtime_session",
        lambda **kwargs: (
            {
                "id": "sess_789",
                "type": "realtime",
                "model": "gpt-realtime-1.5",
                "client_secret": {
                    "value": "ephemeral-secret",
                    "expires_at": 1_775_001_600,
                },
            },
            "gpt-realtime-1.5",
        ),
    )

    payload = connector._rpc_talk_session_create({"relayMcpURL": "https://relay.example.com/v1/talk/mcp?token=test"})  # noqa: SLF001

    assert payload["clientSecret"] == "ephemeral-secret"
    assert payload["session"]["id"] == "sess_789"
    assert payload["session"]["type"] == "realtime"
    assert payload["expiresAt"] == "2026-04-01T00:00:00+00:00"
    assert payload["model"] == "gpt-realtime-1.5"


def test_register_native_mcp_server_updates_existing_hermes_config(monkeypatch, tmp_path):
    hermes_home = tmp_path / ".hermes"
    hermes_home.mkdir(parents=True)
    config_path = hermes_home / "config.yaml"
    config_path.write_text(
        "model: gpt-5.4\n"
        "mcp_servers:\n"
        "  other:\n"
        "    command: other-mcp\n",
        encoding="utf-8",
    )
    monkeypatch.setenv("HERMES_HOME", str(hermes_home))
    monkeypatch.setattr(
        "hermes_mobile_connector.mcp_registration.resolve_mcp_command_path",
        lambda: tmp_path / "bin" / "hermes-mobile-mcp",
    )

    status = register_native_mcp_server(state_dir=tmp_path / "connector-state")
    second_status = register_native_mcp_server(state_dir=tmp_path / "connector-state")

    text = config_path.read_text(encoding="utf-8")
    assert status.registered is True
    assert second_status.registered is True
    assert text.count("hermes_mobile:") == 1
    assert "other:" in text
    assert "HERMES_MOBILE_CONNECTOR_HOME" in text


def test_status_lines_include_core_runtime_details(tmp_path):
    store = ConnectorStateStore(state_dir=tmp_path / "connector-status")
    store.save(
        ConnectorState(
            relay_url="https://relay.example.com/v1",
            web_socket_url="wss://relay.example.com/v1/hosts/ws",
            user_id="user-123",
            host_id="host-123",
            connector_credential="secret",
    
            connector_display_name="Home Mac mini",
            last_connected_at="2026-03-31T16:00:00+00:00",
            mcp_command_path="/tmp/hermes-mobile-mcp",
        )
    )
    connector = HermesMobileConnector(state_store=store, executor=make_executor())
    lines = connector.status_lines()
    assert any("Relay URL: https://relay.example.com/v1" == line for line in lines)
    assert any("User ID: user-123" == line for line in lines)
    assert any("Host ID: host-123" == line for line in lines)
    assert any("Native MCP config: missing" in line or "Native MCP config: present" in line for line in lines)


def test_status_lines_show_mcp_not_configured_hint(tmp_path):
    store = ConnectorStateStore(state_dir=tmp_path / "connector-status-mcp-hint")
    store.save(
        ConnectorState(
            relay_url="https://relay.example.com/v1",
            web_socket_url="wss://relay.example.com/v1/hosts/ws",
            user_id="user-123",
            host_id="host-123",
            connector_credential="secret",
        )
    )
    connector = HermesMobileConnector(state_store=store, executor=make_executor())

    lines = connector.status_lines()

    assert any("MCP validation: not configured" in line for line in lines)


def test_status_lines_keep_mcp_not_configured_hint_when_host_machine_has_native_config(tmp_path):
    store = ConnectorStateStore(state_dir=tmp_path / "connector-status-machine-config")
    store.save(
        ConnectorState(
            relay_url="https://relay.example.com/v1",
            web_socket_url="wss://relay.example.com/v1/hosts/ws",
            user_id="user-123",
            host_id="host-123",
            connector_credential="secret",
            mcp_configured=False,
        )
    )
    connector = HermesMobileConnector(state_store=store, executor=make_executor())

    lines = connector.status_lines()

    assert any("MCP validation: not configured" in line for line in lines)


def test_hermes_runtime_adapter_preserves_history_and_session(monkeypatch):
    executor = make_executor()
    captured: dict = {}

    def fake_send_message(*, latest_user_message, history, session_id):  # noqa: ANN001
        captured["latest_user_message"] = latest_user_message
        captured["history"] = history
        captured["session_id"] = session_id
        return type(
            "FakeResult",
            (),
            {
                "text": "Adapter reply",
                "session_id": "session-456",
            },
        )()

    monkeypatch.setattr(executor, "send_message", fake_send_message)
    adapter = HermesRuntimeAdapter(executor)

    result = adapter.send_text_message(
        latest_user_message="How are you?",
        history=[RuntimeConversationMessage(role="user", text="Hello")],
        session_id="session-123",
    )

    assert result.text == "Adapter reply"
    assert result.session_id == "session-456"
    assert captured["latest_user_message"] == "How are you?"
    assert captured["session_id"] == "session-123"
    assert len(captured["history"]) == 1
    assert captured["history"][0].role == "user"
    assert captured["history"][0].text == "Hello"


def test_rpc_talk_delegate_supports_neutral_and_legacy_method_names(monkeypatch, tmp_path):
    store = ConnectorStateStore(state_dir=tmp_path / "connector-talk-delegate")
    store.save(
        ConnectorState(
            relay_url="https://relay.example.com/v1",
            web_socket_url="wss://relay.example.com/v1/hosts/ws",
            user_id="user-123",
            host_id="host-123",
            connector_credential="secret-token",
        )
    )
    connector = HermesMobileConnector(state_store=store, executor=make_executor())
    captured_prompts: list[str] = []

    class FakeAdapter:
        def send_text_message(self, *, latest_user_message, history, session_id=None):  # noqa: ANN001
            raise AssertionError("send_text_message should not be called")

        def delegate_talk_turn(self, *, prompt, session_id=None):  # noqa: ANN001
            captured_prompts.append(prompt)
            return type("Result", (), {"text": "Delegated reply", "session_id": "voice-session-1"})()

    monkeypatch.setattr(connector, "runtime_adapter_for_state", lambda state: FakeAdapter())

    neutral_response = asyncio.run(
        connector._handle_rpc_request(  # noqa: SLF001
            {
                "requestId": "req-1",
                "method": "talk.delegate",
                "params": {"voiceSessionId": "voice-123", "prompt": "Use tools"},
            }
        )
    )
    legacy_response = asyncio.run(
        connector._handle_rpc_request(  # noqa: SLF001
            {
                "requestId": "req-2",
                "method": "talk.hermes_delegate",
                "params": {"voiceSessionId": "voice-123", "prompt": "Use tools again"},
            }
        )
    )

    assert neutral_response["success"] is True
    assert neutral_response["result"]["text"] == "Delegated reply"
    assert legacy_response["success"] is True
    assert legacy_response["result"]["text"] == "Delegated reply"
    assert captured_prompts == ["Use tools", "Use tools again"]


def test_native_mcp_readiness_requires_reload_when_chat_process_is_running(monkeypatch):
    class FakeProcess:
        returncode = 0
        stdout = " 123 /usr/local/bin/hermes chat\n"

    monkeypatch.setattr(
        "hermes_mobile_connector.mcp_registration.subprocess.run",
        lambda *args, **kwargs: FakeProcess(),
    )

    message = native_mcp_readiness_message(hermes_command="/usr/local/bin/hermes")
    assert message.startswith("Reload required")


def test_native_mcp_readiness_reports_ready_when_no_chat_process_is_running(monkeypatch):
    class FakeProcess:
        returncode = 0
        stdout = " 123 /usr/bin/python something-else\n"

    monkeypatch.setattr(
        "hermes_mobile_connector.mcp_registration.subprocess.run",
        lambda *args, **kwargs: FakeProcess(),
    )

    message = native_mcp_readiness_message(hermes_command="/usr/local/bin/hermes")
    assert message.startswith("Ready now")


def test_state_store_clear_removes_state(tmp_path):
    store = ConnectorStateStore(state_dir=tmp_path / "connector-clear")
    store.save(
        ConnectorState(
            relay_url="https://relay.example.com/v1",
            web_socket_url="wss://relay.example.com/v1/hosts/ws",
            user_id="user-123",
            host_id="host-123",
            connector_credential="secret",
        )
    )
    assert store.state_path.exists()
    store.clear()
    assert not store.state_path.exists()
    assert not store.state_dir.exists()


def test_executor_detects_missing_session_and_extracts_session_id():
    executor = make_executor()
    parsed = executor._parse_cli_output(  # noqa: SLF001
        "╭─ ⚕ Hermes\n↻ Resumed session abc\nsession_id: session-123\nSession not found: session-123"
    )
    assert parsed.session_id == "session-123"
    assert parsed.missing_session is True
