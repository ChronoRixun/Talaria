# Hermes Mobile Relay

FastAPI relay for Hermes Mobile. This service owns device registration, app session bootstrap, push registration, inbox APIs, and Hermes-facing internal inbox hooks.

## Run locally

1. Create a virtual environment and install dependencies.
2. Copy `.env.example` to `.env` and adjust values if needed.
3. Start Postgres and the relay:

```bash
docker compose up --build
```

Or run the API directly:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e .[dev]
uvicorn app.main:app --reload
```

## API surface

- `GET /v1/health`
- `GET /v1/version`
- `POST /v1/device/register`
- `GET /v1/session`
- `POST /v1/auth/refresh`
- `POST /v1/push/register`
- `GET /v1/conversations/current`
- `POST /v1/messages`
- `GET /v1/inbox`
- `POST /v1/inbox/{id}/action`
- `POST /internal/inbox/create`
- `GET /internal/inbox/{id}/actions`

## Wiring a Hermes agent for chat

The first chat integration uses the documented Hermes CLI single-query surface. Set:

```bash
HERMES_ADAPTER=cli
HERMES_COMMAND=/absolute/path/to/hermes
HERMES_WORKDIR=/path/to/your/hermes/project
HERMES_PROVIDER=
HERMES_MODEL=
HERMES_TOOLSETS=
```

The relay will replay the mobile conversation history into `hermes chat -q ...` and persist the returned assistant reply. This is the safest first live strategy because the official docs clearly document `hermes chat -q`, while session-resume composition with `-q` is not explicitly guaranteed.
