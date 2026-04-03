from __future__ import annotations

import contextvars
from dataclasses import dataclass
from urllib.parse import parse_qs

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from mcp.server.fastmcp import FastMCP

from .services import get_voice_session_for_tool_token, record_voice_turn


@dataclass(frozen=True)
class TalkMCPContext:
    voice_session_id: str
    user_id: str
    host_id: str


_current_context: contextvars.ContextVar[TalkMCPContext | None] = contextvars.ContextVar(
    "hermes_mobile_talk_mcp_context",
    default=None,
)


def build_talk_mcp_app(relay_app: FastAPI):
    mcp = FastMCP(
        "hermes-mobile-talk",
        instructions="Relay-hosted bridge for Hermes Mobile talk mode.",
        stateless_http=True,
    )

    @mcp.tool(description="Delegate a voice request to the connected Hermes host.")
    async def hermes_delegate(prompt: str) -> str:
        context = _current_context.get()
        if context is None:
            raise RuntimeError("Talk session context is unavailable.")

        with relay_app.state.database.session() as db:
            record_voice_turn(
                db,
                voice_session_id=context.voice_session_id,
                role="user",
                source="tool",
                text=prompt,
            )

        result = await relay_app.state.send_connector_rpc(
            context.user_id,
            method="talk.delegate",
            params={
                "voiceSessionId": context.voice_session_id,
                "prompt": prompt,
            },
            timeout_seconds=relay_app.state.settings.talk_delegate_timeout_seconds,
        )

        text = str(result.get("text") or "").strip()
        with relay_app.state.database.session() as db:
            record_voice_turn(
                db,
                voice_session_id=context.voice_session_id,
                role="assistant",
                source="tool",
                text=text or "Hermes returned an empty voice delegation result.",
            )
        return text

    inner_app = mcp.streamable_http_app()

    async def protected_app(scope, receive, send) -> None:
        if scope["type"] != "http":
            await inner_app(scope, receive, send)
            return

        token_values = parse_qs(scope.get("query_string", b"").decode("utf-8")).get("token", [])
        relay_tool_token = token_values[0] if token_values else None
        if not relay_tool_token:
            await JSONResponse({"error": "Missing talk tool token."}, status_code=401)(scope, receive, send)
            return

        with relay_app.state.database.session() as db:
            voice_session = get_voice_session_for_tool_token(db, relay_tool_token=relay_tool_token)
        if voice_session is None:
            await JSONResponse({"error": "Invalid or expired talk tool token."}, status_code=401)(scope, receive, send)
            return

        token = _current_context.set(
            TalkMCPContext(
                voice_session_id=voice_session.id,
                user_id=voice_session.user_id,
                host_id=voice_session.host_id,
            )
        )
        try:
            await inner_app(scope, receive, send)
        finally:
            _current_context.reset(token)

    return protected_app
