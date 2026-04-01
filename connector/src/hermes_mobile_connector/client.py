from __future__ import annotations
import asyncio
from dataclasses import dataclass
from datetime import datetime, timezone
import json
import platform as platform_module
import socket

import httpx
from websockets.asyncio.client import connect as websocket_connect

from . import __version__
from .hermes_runner import HermesCLIExecutor, HermesConversationMessage
from .setup_code import decode_host_setup_code
from .state import ConnectorState, ConnectorStateStore


def utcnow_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass(frozen=True)
class ConnectorMetadata:
    platform: str
    hostname: str
    connector_version: str
    hermes_command: str
    hermes_version: str | None
    display_name: str | None = None


class HermesMobileConnector:
    def __init__(
        self,
        *,
        state_store: ConnectorStateStore | None = None,
        executor: HermesCLIExecutor | None = None,
        heartbeat_interval_seconds: float = 10.0,
        reconnect_delay_seconds: float = 3.0,
    ) -> None:
        self.state_store = state_store or ConnectorStateStore()
        self.executor = executor or HermesCLIExecutor()
        self.heartbeat_interval_seconds = heartbeat_interval_seconds
        self.reconnect_delay_seconds = reconnect_delay_seconds

    def metadata(self, *, display_name: str | None = None) -> ConnectorMetadata:
        return ConnectorMetadata(
            platform=platform_module.system().lower(),
            hostname=socket.gethostname(),
            connector_version=__version__,
            hermes_command=self.executor.settings.hermes_command,
            hermes_version=self.executor.detect_version(),
            display_name=display_name,
        )

    def enroll(self, *, code: str, display_name: str | None = None) -> ConnectorState:
        payload = decode_host_setup_code(code.strip())
        metadata = self.metadata(display_name=display_name)

        response = httpx.post(
            f"{payload.relay_url.rstrip('/')}/hosts/redeem",
            json={
                "enrollmentToken": payload.enrollment_token,
                "displayName": display_name,
                "connector": {
                    "platform": metadata.platform,
                    "hostname": metadata.hostname,
                    "connectorVersion": metadata.connector_version,
                    "hermesCommand": metadata.hermes_command,
                    "hermesVersion": metadata.hermes_version,
                },
            },
            timeout=30.0,
        )
        response.raise_for_status()
        data = response.json()["data"]
        state = ConnectorState(
            relay_url=data["relayURL"],
            web_socket_url=data["webSocketURL"],
            host_id=data["host"]["id"],
            connector_credential=data["connectorCredential"],
            connector_display_name=display_name,
            enrolled_at=utcnow_iso(),
        )
        return self.state_store.save(state)

    async def run_forever(self) -> None:
        while True:
            state = self.state_store.load()
            try:
                await self._run_once(state)
            except KeyboardInterrupt:
                raise
            except Exception as error:  # noqa: BLE001
                state.last_error = str(error)
                self.state_store.save(state)
                await asyncio.sleep(self.reconnect_delay_seconds)

    async def _run_once(self, state: ConnectorState) -> None:
        metadata = self.metadata(display_name=state.connector_display_name)
        async with websocket_connect(
            state.web_socket_url,
            additional_headers={"Authorization": f"Bearer {state.connector_credential}"},
        ) as websocket:
            await websocket.send(
                json.dumps(
                    {
                        "type": "hello",
                        "version": 1,
                        "connector": {
                            "platform": metadata.platform,
                            "hostname": metadata.hostname,
                            "connectorVersion": metadata.connector_version,
                            "hermesCommand": metadata.hermes_command,
                            "hermesVersion": metadata.hermes_version,
                            "displayName": metadata.display_name,
                        },
                    }
                )
            )

            ready = json.loads(await websocket.recv())
            if ready.get("type") != "ready":
                raise RuntimeError("Relay did not accept the connector session.")

            state.last_connected_at = utcnow_iso()
            state.last_error = None
            self.state_store.save(state)

            while True:
                try:
                    raw_message = await asyncio.wait_for(
                        websocket.recv(),
                        timeout=self.heartbeat_interval_seconds,
                    )
                except asyncio.TimeoutError:
                    await websocket.send(json.dumps({"type": "heartbeat"}))
                    continue

                message = json.loads(raw_message)
                message_type = message.get("type")
                if message_type == "job.execute":
                    await self._handle_job(websocket, message["job"])
                    continue
                if message_type == "ready":
                    continue
                raise RuntimeError(f"Unsupported relay message: {message_type}")

    async def _handle_job(self, websocket, job: dict) -> None:
        async def execute_job() -> dict:
            try:
                result = await asyncio.to_thread(
                    self.executor.send_message,
                    latest_user_message=job["latestUserMessage"],
                    history=[
                        HermesConversationMessage(role=item["role"], text=item["text"])
                        for item in job.get("history", [])
                    ],
                    session_id=job.get("sessionId"),
                )
                return {
                    "type": "job.result",
                    "jobId": job["id"],
                    "text": result.text,
                    "sessionId": result.session_id,
                }
            except Exception as error:  # noqa: BLE001
                return {
                    "type": "job.failed",
                    "jobId": job["id"],
                    "retryable": False,
                    "error": str(error),
                }

        task = asyncio.create_task(execute_job())
        while True:
            done, _ = await asyncio.wait({task}, timeout=self.heartbeat_interval_seconds)
            if task in done:
                await websocket.send(json.dumps(task.result()))
                return
            await websocket.send(json.dumps({"type": "heartbeat"}))

    def status_lines(self) -> list[str]:
        state = self.state_store.load()
        metadata = self.metadata(display_name=state.connector_display_name)
        return [
            f"Relay URL: {state.relay_url}",
            f"WebSocket URL: {state.web_socket_url}",
            f"Host ID: {state.host_id}",
            f"Hermes command: {metadata.hermes_command}",
            f"Hermes version: {metadata.hermes_version or 'unknown'}",
            f"Last connected: {state.last_connected_at or 'never'}",
            f"Last error: {state.last_error or 'none'}",
        ]
