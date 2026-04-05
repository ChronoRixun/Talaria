"""MCP endpoint for voice mode tool delegation.

Implements the MCP Streamable HTTP protocol directly (no FastMCP dependency)
for a single tool: ``hermes_delegate``.  OpenAI's Realtime API calls this
server-side during voice sessions to delegate requests to the Hermes agent.

The protocol is JSON-RPC 2.0 over HTTP:
  POST /mcp  → JSON-RPC request  → JSON-RPC response
  GET  /mcp  → SSE stream (not used; returns 405)
"""

from __future__ import annotations

import json
import logging
import uuid
from urllib.parse import parse_qs

from fastapi import FastAPI
from fastapi.responses import JSONResponse

from .services import get_voice_session_for_tool_token, record_voice_turn

logger = logging.getLogger(__name__)

# --------------------------------------------------------------------------- #
#  Tool definition advertised via tools/list
# --------------------------------------------------------------------------- #

HERMES_DELEGATE_TOOL = {
    "name": "hermes_delegate",
    "description": "Delegate a voice request to the connected Hermes host. "
                   "Use this when the user asks for something that requires "
                   "tool access, file reads, memory lookups, or any action "
                   "beyond what your cached context provides.",
    "inputSchema": {
        "type": "object",
        "properties": {
            "prompt": {
                "type": "string",
                "description": "The natural-language request to send to Hermes.",
            },
        },
        "required": ["prompt"],
    },
}

MCP_SERVER_INFO = {
    "name": "hermes-mobile-talk",
    "version": "1.0.0",
}

MCP_CAPABILITIES = {
    "tools": {"listChanged": False},
}


# --------------------------------------------------------------------------- #
#  JSON-RPC helpers
# --------------------------------------------------------------------------- #

def _jsonrpc_result(id, result):
    return {"jsonrpc": "2.0", "id": id, "result": result}


def _jsonrpc_error(id, code, message):
    return {"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}}


# --------------------------------------------------------------------------- #
#  Build the ASGI sub-app
# --------------------------------------------------------------------------- #

def build_talk_mcp_app(relay_app: FastAPI):
    """Return a raw ASGI app that speaks MCP Streamable HTTP."""

    async def _handle_hermes_delegate(prompt: str, *, voice_session, user_id: str) -> str:
        """Execute the hermes_delegate tool."""
        with relay_app.state.database.session() as db:
            record_voice_turn(
                db,
                voice_session_id=voice_session.id,
                role="user",
                source="tool",
                text=prompt,
            )

        result = await relay_app.state.send_connector_rpc(
            user_id,
            method="talk.delegate",
            params={
                "voiceSessionId": voice_session.id,
                "prompt": prompt,
            },
            timeout_seconds=relay_app.state.settings.talk_delegate_timeout_seconds,
        )

        text = str(result.get("text") or "").strip()
        with relay_app.state.database.session() as db:
            record_voice_turn(
                db,
                voice_session_id=voice_session.id,
                role="assistant",
                source="tool",
                text=text or "Hermes returned an empty delegation result.",
            )
        return text

    async def _handle_jsonrpc(body: dict, *, voice_session, user_id: str) -> dict:
        """Route a single JSON-RPC request."""
        method = body.get("method", "")
        req_id = body.get("id")
        params = body.get("params", {})

        if method == "initialize":
            return _jsonrpc_result(req_id, {
                "protocolVersion": "2025-03-26",
                "serverInfo": MCP_SERVER_INFO,
                "capabilities": MCP_CAPABILITIES,
            })

        if method == "notifications/initialized":
            # Client acknowledgement — no response needed for notifications
            return None

        if method == "tools/list":
            return _jsonrpc_result(req_id, {"tools": [HERMES_DELEGATE_TOOL]})

        if method == "tools/call":
            tool_name = params.get("name", "")
            arguments = params.get("arguments", {})

            if tool_name != "hermes_delegate":
                return _jsonrpc_error(req_id, -32601, f"Unknown tool: {tool_name}")

            prompt = arguments.get("prompt", "").strip()
            if not prompt:
                return _jsonrpc_error(req_id, -32602, "Missing required argument: prompt")

            try:
                result_text = await _handle_hermes_delegate(
                    prompt, voice_session=voice_session, user_id=user_id,
                )
                return _jsonrpc_result(req_id, {
                    "content": [{"type": "text", "text": result_text}],
                    "isError": False,
                })
            except Exception as exc:
                logger.exception("hermes_delegate failed")
                return _jsonrpc_result(req_id, {
                    "content": [{"type": "text", "text": f"Delegation failed: {exc}"}],
                    "isError": True,
                })

        if method == "ping":
            return _jsonrpc_result(req_id, {})

        return _jsonrpc_error(req_id, -32601, f"Method not found: {method}")

    async def mcp_app(scope, receive, send) -> None:
        if scope["type"] != "http":
            return

        # -- Authenticate via query-string token -------------------------
        qs = scope.get("query_string", b"").decode("utf-8")
        token_values = parse_qs(qs).get("token", [])
        relay_tool_token = token_values[0] if token_values else None

        if not relay_tool_token:
            await JSONResponse(
                {"error": "Missing talk tool token."}, status_code=401,
            )(scope, receive, send)
            return

        with relay_app.state.database.session() as db:
            voice_session = get_voice_session_for_tool_token(db, relay_tool_token=relay_tool_token)
        if voice_session is None:
            await JSONResponse(
                {"error": "Invalid or expired talk tool token."}, status_code=401,
            )(scope, receive, send)
            return

        user_id = voice_session.user_id

        # -- Read the request body ---------------------------------------
        body_parts = []
        while True:
            message = await receive()
            body_parts.append(message.get("body", b""))
            if not message.get("more_body", False):
                break
        raw_body = b"".join(body_parts)

        method = scope.get("method", "GET")

        if method == "GET":
            # SSE stream — not needed for our single-tool server.
            # Return 200 with empty event stream that closes immediately.
            await JSONResponse(
                {"jsonrpc": "2.0", "error": {"code": -32600, "message": "SSE not supported; use POST."}},
                status_code=405,
            )(scope, receive, send)
            return

        if method != "POST":
            await JSONResponse({"error": "Method not allowed"}, status_code=405)(scope, receive, send)
            return

        # -- Parse JSON-RPC ----------------------------------------------
        try:
            body = json.loads(raw_body) if raw_body else {}
        except json.JSONDecodeError:
            await JSONResponse(
                _jsonrpc_error(None, -32700, "Parse error"), status_code=400,
            )(scope, receive, send)
            return

        # Handle batch requests (array of JSON-RPC messages)
        if isinstance(body, list):
            responses = []
            for item in body:
                resp = await _handle_jsonrpc(item, voice_session=voice_session, user_id=user_id)
                if resp is not None:  # skip notifications
                    responses.append(resp)
            if responses:
                await JSONResponse(responses, status_code=200)(scope, receive, send)
            else:
                await JSONResponse(None, status_code=204)(scope, receive, send)
            return

        response = await _handle_jsonrpc(body, voice_session=voice_session, user_id=user_id)
        if response is None:
            # Notification — no response
            await JSONResponse(None, status_code=204)(scope, receive, send)
        else:
            await JSONResponse(response, status_code=200)(scope, receive, send)

    return mcp_app
