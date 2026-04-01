from __future__ import annotations

import base64
import json
from pathlib import Path

from hermes_mobile_connector.client import HermesMobileConnector
from hermes_mobile_connector.hermes_runner import ConnectorHermesSettings, HermesCLIExecutor
from hermes_mobile_connector.setup_code import decode_host_setup_code
from hermes_mobile_connector.state import ConnectorState, ConnectorStateStore


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
    payload = decode_host_setup_code(code)
    assert payload.relay_url == "https://relay.example.com/v1"
    assert payload.enrollment_token == "token-123"


def test_state_store_persists_with_restricted_permissions(tmp_path):
    store = ConnectorStateStore(state_dir=tmp_path / "connector-state")
    state = ConnectorState(
        relay_url="https://relay.example.com/v1",
        web_socket_url="wss://relay.example.com/v1/hosts/ws",
        host_id="host-123",
        connector_credential="secret",
        enrolled_at="2026-03-31T16:00:00+00:00",
    )
    store.save(state)
    loaded = store.load()
    assert loaded.host_id == "host-123"
    assert store.state_path.exists()


def test_status_lines_include_core_runtime_details(tmp_path):
    store = ConnectorStateStore(state_dir=tmp_path / "connector-status")
    store.save(
        ConnectorState(
            relay_url="https://relay.example.com/v1",
            web_socket_url="wss://relay.example.com/v1/hosts/ws",
            host_id="host-123",
            connector_credential="secret",
            last_connected_at="2026-03-31T16:00:00+00:00",
        )
    )
    connector = HermesMobileConnector(state_store=store, executor=HermesCLIExecutor(ConnectorHermesSettings(
        hermes_command="hermes",
        hermes_workdir=None,
        hermes_provider=None,
        hermes_model=None,
        hermes_toolsets=None,
        hermes_source="tool",
        hermes_history_limit=20,
    )))
    lines = connector.status_lines()
    assert any("Relay URL: https://relay.example.com/v1" == line for line in lines)
    assert any("Host ID: host-123" == line for line in lines)


def test_executor_detects_missing_session_and_extracts_session_id():
    executor = HermesCLIExecutor(
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
    parsed = executor._parse_cli_output(  # noqa: SLF001
        "╭─ ⚕ Hermes\n↻ Resumed session abc\nsession_id: session-123\nSession not found: session-123"
    )
    assert parsed.session_id == "session-123"
    assert parsed.missing_session is True
