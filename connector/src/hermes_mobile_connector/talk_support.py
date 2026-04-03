from __future__ import annotations

from datetime import datetime, timezone
import os
from pathlib import Path

from .sensor_store import SensorStore
from .state import VoiceContextSnapshot

DEFAULT_REALTIME_MODELS = ["gpt-realtime-1.5", "gpt-realtime"]
DEFAULT_REALTIME_VOICE = "verse"
VOICE_CONTEXT_MAX_CHARS = 4000


def utcnow_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def resolve_hermes_home(explicit_home: str | None = None) -> Path:
    configured = explicit_home or os.getenv("HERMES_HOME")
    if configured:
        return Path(configured).expanduser()
    return Path.home() / ".hermes"


def read_memory_file(path: Path, *, max_chars: int = VOICE_CONTEXT_MAX_CHARS) -> str:
    if not path.exists():
        return "(not available)"

    content = path.read_text(encoding="utf-8").strip()
    if not content:
        return "(empty)"
    if len(content) <= max_chars:
        return content
    return f"{content[:max_chars].rstrip()}\n\n[truncated]"


def summarize_sensor_freshness(sensor_store: SensorStore) -> str:
    freshness = sensor_store.get_sensor_freshness_summary()
    location = freshness.get("location")
    health = freshness.get("health", {})

    if location is None:
        location_summary = "No recent location reading is available."
    else:
        state = "stale" if location["stale"] else "fresh"
        location_summary = (
            f"Current location context is {state}, recorded {location['ageSeconds']} seconds ago."
        )

    health_summary = (
        "Health context has "
        f"{health.get('freshCount', 0)} fresh metrics, "
        f"{health.get('staleCount', 0)} stale metrics, "
        f"and {health.get('count', 0)} total metrics."
    )
    return f"{location_summary} {health_summary}"


def build_voice_context_snapshot(
    *,
    sensor_store: SensorStore,
    hermes_home: str | None,
    readiness_summary: str,
) -> VoiceContextSnapshot:
    resolved_home = resolve_hermes_home(hermes_home)
    memories_dir = resolved_home / "memories"
    memory_summary = read_memory_file(memories_dir / "MEMORY.md")
    user_summary = read_memory_file(memories_dir / "USER.md")
    sensor_summary = summarize_sensor_freshness(sensor_store)
    system_prompt = render_voice_system_prompt(
        memory_summary=memory_summary,
        user_summary=user_summary,
        sensor_summary=sensor_summary,
        readiness_summary=readiness_summary,
    )
    return VoiceContextSnapshot(
        system_prompt=system_prompt,
        memory_summary=memory_summary,
        user_summary=user_summary,
        sensor_summary=sensor_summary,
        readiness_summary=readiness_summary,
        updated_at=utcnow_iso(),
    )


def render_voice_system_prompt(
    *,
    memory_summary: str,
    user_summary: str,
    sensor_summary: str,
    readiness_summary: str,
) -> str:
    return (
        "You are Hermes speaking through Hermes Mobile talk mode.\n"
        "Keep responses conversational, crisp, and natural for live duplex voice.\n"
        "You may answer directly from the cached context below when it is enough.\n"
        "When you need deeper memory, tool use, or a more deliberate agentic action, call the "
        "`hermes_delegate` tool instead of guessing.\n"
        "Do not mention internal implementation details unless the user asks.\n\n"
        "Cached Hermes memory:\n"
        f"{memory_summary}\n\n"
        "Cached user profile:\n"
        f"{user_summary}\n\n"
        "Current sensor freshness:\n"
        f"{sensor_summary}\n\n"
        "Hermes tool readiness:\n"
        f"{readiness_summary}"
    )
