from __future__ import annotations

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


class HermesAdapter(Protocol):
    def send_message(self, *, latest_user_message: str, history: list[HermesConversationMessage]) -> HermesChatResult:
        ...


class MockHermesAdapter:
    def send_message(self, *, latest_user_message: str, history: list[HermesConversationMessage]) -> HermesChatResult:
        return HermesChatResult(text=f"Mock Hermes reply: {latest_user_message}")


class CLIHermesAdapter:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def send_message(self, *, latest_user_message: str, history: list[HermesConversationMessage]) -> HermesChatResult:
        if shutil.which(self.settings.hermes_command) is None:
            raise RuntimeError(f"Hermes command not found: {self.settings.hermes_command}")

        prompt = self._build_prompt(latest_user_message=latest_user_message, history=history)
        command = [self.settings.hermes_command, "chat", "-q", prompt]

        if self.settings.hermes_provider:
            command.extend(["--provider", self.settings.hermes_provider])
        if self.settings.hermes_model:
            command.extend(["--model", self.settings.hermes_model])
        if self.settings.hermes_toolsets:
            command.extend(["--toolsets", self.settings.hermes_toolsets])

        completed = subprocess.run(
            command,
            cwd=self.settings.hermes_workdir or None,
            capture_output=True,
            text=True,
            check=False,
        )

        if completed.returncode != 0:
            raise RuntimeError(completed.stderr.strip() or "Hermes CLI request failed.")

        response_text = completed.stdout.strip()
        if not response_text:
            raise RuntimeError("Hermes CLI returned an empty response.")

        return HermesChatResult(text=response_text)

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
