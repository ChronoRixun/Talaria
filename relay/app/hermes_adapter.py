from __future__ import annotations

import re
import shutil
import subprocess
from dataclasses import dataclass
from typing import Protocol

from .config import Settings


@dataclass(frozen=True)
class HermesConversationMessage:
    role: str
    text: str


@dataclass(frozen=True)
class HermesChatResult:
    text: str
    session_id: str | None = None


@dataclass(frozen=True)
class CLIHermesResponse:
    text: str
    session_id: str | None
    missing_session: bool = False


class HermesAdapter(Protocol):
    def send_message(
        self,
        *,
        latest_user_message: str,
        history: list[HermesConversationMessage],
        session_id: str | None = None,
    ) -> HermesChatResult:
        ...


class MockHermesAdapter:
    def send_message(
        self,
        *,
        latest_user_message: str,
        history: list[HermesConversationMessage],
        session_id: str | None = None,
    ) -> HermesChatResult:
        return HermesChatResult(text=f"Mock Hermes reply: {latest_user_message}")


class CLIHermesAdapter:
    SESSION_ID_PATTERN = re.compile(r"(?m)^session_id:\s*(?P<session_id>\S+)\s*$")

    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def send_message(
        self,
        *,
        latest_user_message: str,
        history: list[HermesConversationMessage],
        session_id: str | None = None,
    ) -> HermesChatResult:
        if shutil.which(self.settings.hermes_command) is None:
            raise RuntimeError(f"Hermes command not found: {self.settings.hermes_command}")

        response = self._send_with_resume(
            latest_user_message=latest_user_message,
            history=history,
            session_id=session_id,
        )

        if response.missing_session and session_id:
            response = self._send_with_replay(latest_user_message=latest_user_message, history=history)

        if not response.text:
            raise RuntimeError("Hermes CLI returned an empty response.")

        return HermesChatResult(text=response.text, session_id=response.session_id or session_id)

    def _send_with_resume(
        self,
        *,
        latest_user_message: str,
        history: list[HermesConversationMessage],
        session_id: str | None,
    ) -> CLIHermesResponse:
        if session_id:
            command = self._build_command(query=latest_user_message, session_id=session_id)
            return self._run_command(command)
        return self._send_with_replay(latest_user_message=latest_user_message, history=history)

    def _send_with_replay(
        self,
        *,
        latest_user_message: str,
        history: list[HermesConversationMessage],
    ) -> CLIHermesResponse:
        prompt = self._build_prompt(latest_user_message=latest_user_message, history=history)
        return self._run_command(self._build_command(query=prompt))

    def _build_command(self, *, query: str, session_id: str | None = None) -> list[str]:
        command = [self.settings.hermes_command, "chat", "-Q", "-q", query]

        if session_id:
            command.extend(["--resume", session_id])
        if self.settings.hermes_provider:
            command.extend(["--provider", self.settings.hermes_provider])
        if self.settings.hermes_model:
            command.extend(["--model", self.settings.hermes_model])
        if self.settings.hermes_toolsets:
            command.extend(["--toolsets", self.settings.hermes_toolsets])
        if self.settings.hermes_source:
            command.extend(["--source", self.settings.hermes_source])

        return command

    def _run_command(self, command: list[str]) -> CLIHermesResponse:
        completed = subprocess.run(
            command,
            cwd=self.settings.hermes_workdir or None,
            capture_output=True,
            text=True,
            check=False,
        )

        if completed.returncode != 0:
            error_text = completed.stderr.strip() or completed.stdout.strip() or "Hermes CLI request failed."
            raise RuntimeError(error_text)

        return self._parse_cli_output(completed.stdout)

    def _parse_cli_output(self, output: str) -> CLIHermesResponse:
        session_match = self.SESSION_ID_PATTERN.search(output)
        session_id = session_match.group("session_id") if session_match else None
        body = self.SESSION_ID_PATTERN.sub("", output).strip()

        lines = body.splitlines()
        while lines and self._is_metadata_line(lines[0]):
            lines.pop(0)

        text = "\n".join(lines).strip()
        return CLIHermesResponse(
            text=text,
            session_id=session_id,
            missing_session=text.startswith("Session not found:"),
        )

    def _is_metadata_line(self, line: str) -> bool:
        stripped = line.strip()
        return (
            not stripped
            or stripped.startswith("↻ Resumed session ")
            or stripped.startswith("╭─ ⚕ Hermes")
        )

    def _build_prompt(self, *, latest_user_message: str, history: list[HermesConversationMessage]) -> str:
        history_lines = []
        for message in history[-self.settings.hermes_history_limit :]:
            prefix = "User" if message.role == "user" else "Hermes"
            history_lines.append(f"{prefix}: {message.text}")

        transcript = "\n".join(history_lines) if history_lines else "(no prior messages)"

        return (
            "You are Hermes responding inside Hermes Mobile.\n"
            "Continue the conversation naturally using the history below.\n"
            "Return only the next assistant reply.\n\n"
            f"Conversation history:\n{transcript}\n\n"
            f"Latest user message:\nUser: {latest_user_message}"
        )


def build_hermes_adapter(settings: Settings) -> HermesAdapter:
    if settings.hermes_adapter == "cli":
        return CLIHermesAdapter(settings)
    return MockHermesAdapter()
