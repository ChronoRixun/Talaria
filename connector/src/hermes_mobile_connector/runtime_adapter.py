from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

from .hermes_runner import HermesCLIExecutor, HermesConversationMessage


@dataclass(frozen=True)
class RuntimeConversationMessage:
    role: str
    text: str


@dataclass(frozen=True)
class RuntimeTurnResult:
    text: str
    session_id: str | None = None


class HostRuntimeAdapter(Protocol):
    def send_text_message(
        self,
        *,
        latest_user_message: str,
        history: list[RuntimeConversationMessage],
        session_id: str | None = None,
    ) -> RuntimeTurnResult: ...

    def delegate_talk_turn(
        self,
        *,
        prompt: str,
        session_id: str | None = None,
    ) -> RuntimeTurnResult: ...


class HermesRuntimeAdapter:
    def __init__(self, executor: HermesCLIExecutor) -> None:
        self.executor = executor

    def send_text_message(
        self,
        *,
        latest_user_message: str,
        history: list[RuntimeConversationMessage],
        session_id: str | None = None,
    ) -> RuntimeTurnResult:
        result = self.executor.send_message(
            latest_user_message=latest_user_message,
            history=[
                HermesConversationMessage(role=message.role, text=message.text)
                for message in history
            ],
            session_id=session_id,
        )
        return RuntimeTurnResult(text=result.text, session_id=result.session_id)

    def delegate_talk_turn(
        self,
        *,
        prompt: str,
        session_id: str | None = None,
    ) -> RuntimeTurnResult:
        result = self.executor.send_message(
            latest_user_message=prompt,
            history=[],
            session_id=session_id,
        )
        return RuntimeTurnResult(text=result.text, session_id=result.session_id)
