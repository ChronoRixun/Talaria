"""MCP server exposing location and health sensor data to Hermes agents.

Run as:  hermes-mobile-mcp
Configure in ~/.hermes/config.yaml:
    mcp_servers:
      hermes_mobile:
        command: "/path/to/.venv/bin/hermes-mobile-mcp"
"""

from __future__ import annotations

import json
import os
from pathlib import Path

from mcp.server.fastmcp import FastMCP

from .sensor_store import (
    HEALTH_STALE_AFTER_SECONDS,
    LOCATION_STALE_AFTER_SECONDS,
    SensorStore,
    freshness_metadata,
)
from .state import ConnectorStateStore

mcp = FastMCP("hermes-mobile", instructions="Provides real-time location and health data from the user's phone.")


def _get_store() -> SensorStore:
    state_store = ConnectorStateStore()
    db_path = state_store.state_dir / "sensors.db"
    return SensorStore(db_path)


@mcp.tool()
def get_user_location() -> str:
    """Get the user's current location (latitude, longitude, address).

    Returns the most recent location reading from the user's phone.
    Use this when the user asks about their current location, wants
    nearby recommendations, or needs location-aware assistance.
    """
    store = _get_store()
    try:
        current = store.get_current_location()
        if current is None:
            return json.dumps({"error": "No location data available yet. The user's phone may not have sent a location update."})
        return json.dumps(
            {
                "latitude": current.latitude,
                "longitude": current.longitude,
                "altitude": current.altitude,
                "accuracy": current.accuracy,
                "address": current.address,
                **freshness_metadata(
                    recorded_at=current.recorded_at,
                    updated_at=current.updated_at,
                    stale_after_seconds=LOCATION_STALE_AFTER_SECONDS,
                ),
            }
        )
    finally:
        store.close()


@mcp.tool()
def get_location_history(since: str | None = None, limit: int = 50) -> str:
    """Get the user's recent location history.

    Returns a trail of location readings ordered newest first.
    Use this for queries like "where have I been today" or to understand
    the user's travel patterns.

    Args:
        since: ISO8601 timestamp to filter from (e.g. "2026-04-01T00:00:00Z")
        limit: Maximum number of entries to return (default 50)
    """
    store = _get_store()
    try:
        history = store.get_location_history(since=since, limit=limit)
        return json.dumps(
            {
                "locations": history,
                "count": len(history),
                "current": store.get_location_freshness(),
            }
        )
    finally:
        store.close()


@mcp.tool()
def get_health_summary() -> str:
    """Get a summary of all the user's latest health metrics.

    Returns current values for all tracked health metrics (steps, heart rate,
    calories, sleep, etc). Use this for general health queries or when the
    user asks about their overall health status.
    """
    store = _get_store()
    try:
        summary = store.get_health_summary()
        return json.dumps(summary)
    finally:
        store.close()


@mcp.tool()
def get_health_metric(metric: str, since: str | None = None, limit: int = 50) -> str:
    """Get time-series data for a specific health metric.

    Returns historical samples for the requested metric ordered newest first.
    Available metrics include: steps, heart_rate, resting_heart_rate, calories,
    active_calories, sleep_hours, distance_walking, distance_cycling, workouts.

    Args:
        metric: The metric name (e.g. "steps", "heart_rate", "sleep_hours")
        since: ISO8601 timestamp to filter from (e.g. "2026-04-01T00:00:00Z")
        limit: Maximum number of samples to return (default 50)
    """
    store = _get_store()
    try:
        samples = store.get_health_metric(metric, since=since, limit=limit)
        latest_freshness = store.get_metric_freshness(metric)
        return json.dumps(
            {
                "metric": metric,
                "samples": samples,
                "count": len(samples),
                "latest": latest_freshness,
            }
        )
    finally:
        store.close()


@mcp.tool()
def get_health_metrics_list() -> str:
    """List all available health metrics and their latest values.

    Returns the names of all health metrics that have been recorded,
    along with their most recent values. Use this to discover what
    health data is available before querying specific metrics.
    """
    store = _get_store()
    try:
        metrics = store.get_latest_metrics()
        return json.dumps(
            {
                "metrics": [
                    {
                        "metric": m.metric,
                        "value": m.value,
                        "unit": m.unit,
                        **freshness_metadata(
                            recorded_at=m.recorded_at,
                            updated_at=m.updated_at,
                            stale_after_seconds=HEALTH_STALE_AFTER_SECONDS,
                        ),
                    }
                    for m in metrics
                ],
                "count": len(metrics),
            }
        )
    finally:
        store.close()


@mcp.tool()
def get_sensor_schema() -> str:
    """Return the SQLite schema for the sensor database.

    Shows all table definitions, column types, and indexes.
    Use this to understand the data structure before writing
    custom queries with query_sensor_data.
    """
    store = _get_store()
    try:
        conn = store._conn
        cursor = conn.execute(
            "SELECT sql FROM sqlite_master WHERE type IN ('table', 'index') AND sql IS NOT NULL ORDER BY type, name"
        )
        statements = [row[0] for row in cursor.fetchall()]
        return json.dumps({"schema": statements})
    finally:
        store.close()


@mcp.tool()
def query_sensor_data(sql: str, limit: int = 100) -> str:
    """Run a read-only SQL query against the sensor database.

    Use this for custom analysis, trend queries, aggregations, or
    building dashboards. The database contains tables: location_current,
    location_history, health_samples, health_latest, health_daily.

    Args:
        sql: A SELECT query. Only SELECT statements are allowed.
        limit: Maximum rows to return (default 100, max 1000).

    Example queries:
        - "SELECT metric, AVG(value) FROM health_samples WHERE metric='steps' GROUP BY date(start_at)"
        - "SELECT * FROM location_history ORDER BY recorded_at DESC LIMIT 10"
        - "SELECT metric, value, unit FROM health_latest"
    """
    # Safety checks
    stripped = sql.strip().upper()
    if not stripped.startswith("SELECT"):
        return json.dumps({"error": "Only SELECT queries are allowed."})

    forbidden = {"DROP", "DELETE", "INSERT", "UPDATE", "ALTER", "CREATE", "ATTACH", "DETACH", "PRAGMA"}
    first_words = set(stripped.split()[:3])
    if first_words & forbidden:
        return json.dumps({"error": "Destructive or administrative statements are not allowed."})

    effective_limit = min(max(limit, 1), 1000)

    store = _get_store()
    try:
        # Open a separate read-only connection for user queries.
        # Even if the SQL contains injection (DROP, INSERT, ATTACH, etc.),
        # the read-only mode prevents any writes at the SQLite level.
        import sqlite3
        ro_conn = sqlite3.connect(f"file:{store.db_path}?mode=ro", uri=True)
        ro_conn.row_factory = sqlite3.Row
        try:
            safe_sql = f"SELECT * FROM ({sql.rstrip().rstrip(';')}) LIMIT {effective_limit}"
            cursor = ro_conn.execute(safe_sql)
            columns = [desc[0] for desc in cursor.description] if cursor.description else []
            rows = cursor.fetchall()
            return json.dumps({
                "columns": columns,
                "rows": [dict(zip(columns, row)) for row in rows],
                "count": len(rows),
            })
        finally:
            ro_conn.close()
    except Exception as e:
        return json.dumps({"error": str(e)})
    finally:
        store.close()


def main() -> None:
    mcp.run()


if __name__ == "__main__":
    main()
