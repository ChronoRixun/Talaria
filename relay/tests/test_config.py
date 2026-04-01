from __future__ import annotations

from app.config import normalize_database_url


def test_normalize_database_url_maps_postgres_urls_to_psycopg():
    assert (
        normalize_database_url("postgresql://user:pass@db.example.com/app")
        == "postgresql+psycopg://user:pass@db.example.com/app"
    )
    assert (
        normalize_database_url("postgres://user:pass@db.example.com/app")
        == "postgresql+psycopg://user:pass@db.example.com/app"
    )
    assert normalize_database_url("sqlite:///./relay.db") == "sqlite:///./relay.db"
