# Hermes Mobile Self-Hosting and Deployment Strategy

## Goal
Define a deployment strategy that works for both:
- a mass-distributed first-party hosted Hermes Mobile product
- an open-source, user-self-hosted version

The strategy should avoid provider lock-in while still giving a strong recommended production path.

---

## Core recommendation
Build the relay/backend as provider-neutral infrastructure.

That means:
- container-first packaging
- env-driven configuration
- externalized secrets
- standard Postgres support
- optional Redis, not mandatory Redis
- no Fly.io-specific assumptions in business logic
- no provider-specific identity model in the API contract

Then support two deployment modes:
1. official hosted deployment
2. self-host deployment

---

## Official hosted deployment recommendation
Recommended default:
- Fly.io for managed production deployment

Recommended hosted topology:
- relay API service
- optional background worker service
- Postgres
- object storage if media is enabled
- APNs credentials stored in provider-managed secrets

Why Fly.io is a strong fit:
- good global placement story
- works well for containerized APIs and WebSockets
- easy path to multiple internal services later
- good fit if Hermes runtime or adjacent worker services eventually need private networking

Alternative hosted deployment:
- Render

Choose Render when:
- you want the lowest operational friction
- you are okay with a simpler regional setup initially
- you want a straightforward API + worker + database deployment path

---

## Self-host deployment recommendation
Recommended default for open-source users:
- Docker Compose

Why Docker Compose should be the reference path:
- easy for homelab users
- easy for a cheap VPS
- portable across providers
- easy for coding agents to reason about and maintain
- lowest-friction path for open-source adoption

Recommended self-host reference stack:
- `relay` container
- optional `worker` container
- `postgres` container or external Postgres
- optional `redis` container
- reverse proxy only if needed for TLS outside the hosting platform

The self-host docs should not require Fly.io.
Fly.io should be one documented option, not the only one.

---

## Configuration model
All deployments should use the same logical configuration categories.

### Core env vars
- app environment
- public app base URL
- database URL
- optional Redis URL
- APNs key ID
- APNs team ID
- APNs bundle ID / topic
- path or secret ref for APNs `.p8` material
- OpenAI or provider server-side root key for ephemeral issuance only
- auth/session signing secret
- object storage credentials if media uploads are enabled

### Do not do this
- do not store provider root keys in the iOS app
- do not tie config layout to Fly-only secret primitives
- do not make Redis mandatory before it is truly needed

---

## Recommended repository layout for deployment
If the project becomes multi-part, a clean structure is:

```text
hermes-mobile/
├── ios-app/
├── relay/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── docs/
│   │   ├── deploy-fly.md
│   │   ├── deploy-render.md
│   │   └── deploy-self-host.md
│   └── src/
└── docs/
```

This keeps the relay deployable independently of the app.

---

## Deployment tiers

### Tier 1: Local development
Goal:
- easiest path for app + relay integration during development

Suggested stack:
- local relay server
- local or hosted Postgres
- mocked APNs unless specifically testing push

### Tier 2: Single-region production
Goal:
- simplest real hosted deployment

Suggested stack:
- one relay API instance
- one database
- optional worker

Good for:
- early hosted beta
- initial App Store release

### Tier 3: Multi-region production
Goal:
- better global latency and redundancy

Suggested stack:
- Fly.io multi-region relay or a front-door plus regional services
- managed Postgres strategy with careful consistency design
- optional Redis or event bus if needed

Good for:
- broad geographic distribution
- higher throughput realtime and notification workflows

---

## Self-host support policy recommendation
If open sourcing, document support expectations clearly.

Suggested support tiers:
- officially supported: Docker Compose
- documented but lighter support: Fly.io
- community-supported: generic VPS, Kubernetes, other providers

This keeps maintenance load realistic.

---

## APNs deployment requirement
Any hosted or self-hosted deployment that wants push must support:
- valid APNs credentials
- correct app bundle/topic configuration
- HTTPS-accessible endpoints for app registration flows

For self-hosters, provide a separate push setup section because APNs setup is often the hardest operational step.

---

## Realtime session issuance requirement
The relay should own issuance of ephemeral voice session credentials.

Why:
- protects provider root secrets
- keeps pricing/policy control server-side
- works the same in hosted and self-hosted modes

This must be consistent across all deployment models.

---

## Recommendation summary
If you want one strategy that works across all futures:
- architect provider-neutral
- ship Docker Compose first for self-hosters
- deploy your own managed version on Fly.io
- keep Render documented as the lower-ops hosted alternative

## Acceptance criteria
This deployment strategy is complete when:
- the relay can run locally and in Docker without provider-specific code changes
- hosted deployment can target Fly.io cleanly
- self-host docs can target a generic VPS or homelab
- no part of the core backend assumes one hosting vendor
