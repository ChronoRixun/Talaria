# Hermes iOS Relay

The relay is the public control plane for Hermes iOS:

- pairing and auth
- durable message jobs
- SSE streaming
- connector WebSocket control channel
- voice session bootstrap
- inbox and push APIs

In connector mode, the relay does **not** run Hermes itself. Hermes work executes on the user-owned machine through the connector.

## Local Development

```bash
cd relay
python -m venv .venv
source .venv/bin/activate
pip install -e .[dev]
cp .env.example .env
docker compose up --build
```

Or run the API directly after setting your env vars:

```bash
uvicorn app.main:app --reload
```

See [docs/local-dev.md](docs/local-dev.md) for local notes and [../docs/CONFIGURATION.md](../docs/CONFIGURATION.md) for the full config matrix.

## Production Mode

For real deployments, use connector mode:

```bash
HERMES_ADAPTER=connector
PUBLIC_BASE_URL=https://your-relay.example.com/v1
CONNECTOR_SETUP_SECRET=
```

If `CONNECTOR_SETUP_SECRET` is set, every connector must send the same value during `hermes-mobile setup`.

## Fly.io

Fly is just one deployment target. The tracked [fly.toml](fly.toml) now contains generic placeholders and must be customized before deploy.

See [docs/fly-io.md](docs/fly-io.md).

## API surface

### Core and auth

- `GET /v1/health`
- `GET /v1/version`
- `GET /v1/session`
- `POST /v1/auth/refresh`
- `POST /v1/auth/revoke`
- `POST /v1/device/register`

### Connector-first pairing and host management

- `POST /v1/connector/setup`
- `POST /v1/connector/phone-pairing-codes`
- `POST /v1/phone-pairing/redeem`
- `POST /v1/pairing/redeem` (legacy/dev compatibility)
- `POST /v1/hosts/enrollment-codes` (legacy/dev compatibility)
- `POST /v1/hosts/redeem` (legacy/dev compatibility)
- `GET /v1/hosts/current`
- `POST /v1/hosts/current/revoke`
- `GET /v1/hosts/ws` (WebSocket)

### Chat and streaming

- `GET /v1/conversations/current`
- `POST /v1/messages`
- `GET /v1/jobs/{job_id}/events`

### Talk mode

- `GET /v1/talk/readiness`
- `POST /v1/talk/session`
- `POST /v1/talk/session/{voice_session_id}/end`
- `POST /v1/talk/session/{voice_session_id}/turns`

### Inbox and push

- `GET /v1/inbox`
- `POST /v1/inbox/{id}/action`
- `POST /v1/push/register`
- `POST /v1/push/send` *(internal)* — send silent/alert push to user's devices
- `POST /internal/inbox/create`
- `GET /internal/inbox/{id}/actions`

## Hermes execution modes

The relay supports three Hermes execution modes:

- `HERMES_ADAPTER=mock`
  - deterministic local/demo behavior
- `HERMES_ADAPTER=cli`
  - the relay shells out to Hermes locally, useful for same-machine development and smoke tests
- `HERMES_ADAPTER=connector`
  - production-oriented mode where the relay persists jobs and a connected host connector claims and executes them

For local CLI mode, set:

```bash
HERMES_ADAPTER=cli
HERMES_COMMAND=/absolute/path/to/hermes
HERMES_WORKDIR=/path/to/your/hermes/project
HERMES_PROVIDER=
HERMES_MODEL=
HERMES_TOOLSETS=
HERMES_SOURCE=tool
```

For connector mode, set:

```bash
HERMES_ADAPTER=connector
PUBLIC_BASE_URL=https://your.public.relay.example/v1
PHONE_PAIRING_CODE_TTL_SECONDS=600
PHONE_PAIRING_MAX_ATTEMPTS_PER_CODE=5
PHONE_PAIRING_MAX_ATTEMPTS_PER_IP=5
PHONE_PAIRING_RATE_LIMIT_WINDOW_SECONDS=300
HOST_ENROLLMENT_CODE_TTL_SECONDS=900
CONNECTOR_SYNC_WAIT_SECONDS=25
CONNECTOR_JOB_LEASE_SECONDS=180
CONNECTOR_HEARTBEAT_TIMEOUT_SECONDS=30
CONNECTOR_IDLE_POLL_INTERVAL_SECONDS=1.0
CONNECTOR_SETUP_SECRET=
```

## Connector mode behavior

In connector mode the relay:

- never shells out to Hermes directly
- persists user messages before queuing work
- stores message jobs durably in the database
- lets a connected host claim jobs over WebSocket
- supports synchronous inline replies when the host finishes within the sync window
- falls back to pending/queued replies when the host is offline or slow
- streams job progress over SSE
- persists final assistant output and optional inline diff metadata

## Sensor delivery

Sensor delivery in connector mode is relay-stateless.

- the phone uploads location and health samples only when paired and authenticated
- the relay forwards them over the live connector control channel
- a request is treated as delivered only after the connector ACKs local storage
- if the host is offline or unavailable, the relay returns `202` with `deliveryState=retry`
- the phone keeps the payload in its local outbox until a later successful delivery

## Talk mode

The relay is the control plane for voice sessions.

It currently provides:

- talk readiness checks
- short-lived Realtime bootstrap from the host connector
- one active voice session per user in v1
- relay-hosted `hermes_delegate` MCP bridging for talk sessions
- persisted final voice turns

The relay does not proxy live audio. Media flows directly between the app and OpenAI Realtime once the session is bootstrapped.

## Connector-first setup

On the machine where Hermes lives:

```bash
cd connector
python -m venv .venv
source .venv/bin/activate
pip install -e .[dev]

export HERMES_COMMAND=/absolute/path/to/hermes
export HERMES_WORKDIR=/path/to/your/hermes/project
export HERMES_MOBILE_RELAY_URL=https://your-relay.example.com/v1
# Optional, if the relay requires it:
export CONNECTOR_SETUP_SECRET=replace-me

hermes-mobile setup
hermes-mobile pair-phone
hermes-mobile service install
hermes-mobile service start
```

`pair-phone` prints the short-lived manual code plus an ASCII QR. The iOS app expects that connector-generated phone pairing code instead of the older HM1/HC1 flow.

`setup` can also:

- auto-register `mcp_servers.hermes_mobile` in the local Hermes config
- validate that MCP entry with `hermes mcp test hermes_mobile`
- configure connector-owned OpenAI Realtime talk settings

If Hermes chat is already open, the connector may report `Reload required`. Run `/reload-mcp` or start a fresh chat before expecting new MCP tools to appear in that active Hermes session.

## Current limitations

- Talk mode bootstrap and persistence are implemented, but true barge-in interruption is still incomplete in the app layer.
- Inline code diffs are connector-generated from git-visible filesystem changes, not a Hermes-native structured diff API.
- Background health delivery and Always-authorized location still require physical-device validation.
