from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import load_dotenv


load_dotenv()


@dataclass(frozen=True)
class Settings:
    service_name: str = "hermes-mobile-relay"
    version: str = "0.1.0"
    environment: str = "development"
    public_base_url: str = "http://127.0.0.1:8000/v1"
    database_url: str = "sqlite:///./relay.db"
    internal_api_key: str = "replace-me"
    access_token_ttl_seconds: int = 3600
    refresh_token_ttl_seconds: int = 60 * 60 * 24 * 30
    default_user_display_name: str = "Hermes User"
    hermes_adapter: str = "mock"
    hermes_command: str = "hermes"
    hermes_workdir: str | None = None
    hermes_provider: str | None = None
    hermes_model: str | None = None
    hermes_toolsets: str | None = None
    hermes_history_limit: int = 20

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            environment=os.getenv("RELAY_ENVIRONMENT", "development"),
            public_base_url=os.getenv("PUBLIC_BASE_URL", "http://127.0.0.1:8000/v1"),
            database_url=os.getenv("DATABASE_URL", "sqlite:///./relay.db"),
            internal_api_key=os.getenv("INTERNAL_API_KEY", "replace-me"),
            access_token_ttl_seconds=int(os.getenv("ACCESS_TOKEN_TTL_SECONDS", "3600")),
            refresh_token_ttl_seconds=int(os.getenv("REFRESH_TOKEN_TTL_SECONDS", str(60 * 60 * 24 * 30))),
            default_user_display_name=os.getenv("DEFAULT_USER_DISPLAY_NAME", "Hermes User"),
            hermes_adapter=os.getenv("HERMES_ADAPTER", "mock"),
            hermes_command=os.getenv("HERMES_COMMAND", "hermes"),
            hermes_workdir=os.getenv("HERMES_WORKDIR") or None,
            hermes_provider=os.getenv("HERMES_PROVIDER") or None,
            hermes_model=os.getenv("HERMES_MODEL") or None,
            hermes_toolsets=os.getenv("HERMES_TOOLSETS") or None,
            hermes_history_limit=int(os.getenv("HERMES_HISTORY_LIMIT", "20")),
        )
