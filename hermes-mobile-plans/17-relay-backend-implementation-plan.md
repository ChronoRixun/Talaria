# Hermes Mobile Relay Backend Implementation Plan

## Goal
Build the first real Hermes Mobile relay/backend service that sits between the iOS app, Hermes runtime, APNs, and provider integrations.

This plan is intentionally provider-neutral at the application layer, even if the first managed deployment target is Fly.io.

## Architecture summary
The relay should be a small durable service responsible for:
- device registration
- auth/session bootstrap
- conversation/session metadata
- inbox items and actions
- push registration
- ephemeral realtime session issuance
- capability result ingestion
- media upload plumbing
- Hermes-facing integration hooks

Suggested first implementation stack:
- FastAPI or Node/TypeScript
- Postgres
- optional Redis later
- Dockerized from the start

---

## Phase R1: Repo and service bootstrap

### Objective
Create a standalone relay service with a clean local/dev/prod configuration model.

### Deliverables
- relay service directory
- Dockerfile
- `.env.example`
- local run instructions
- database connection setup
- health endpoint

### Minimum routes
- `GET /health`
- `GET /version`

### Acceptance
- relay runs locally via Docker or native dev command
- configuration is env-driven

---

## Phase R2: Data model foundation

### Objective
Define the first durable models.

### Recommended tables or collections
- users
- devices
- app_sessions or session_state
- conversations
- messages
- inbox_items
- inbox_actions or inbox_events
- push_registrations
- capability_requests
- capability_results
- audit_log

### Notes
Keep schemas simple. Do not over-model future edge cases before the app flow is stable.

### Acceptance
- schema supports device registration, inbox, and chat basics

---

## Phase R3: Device registration and session bootstrap

### Objective
Allow the iOS app to identify itself and obtain baseline session state.

### Endpoints
- `POST /device/register`
- `GET /session`
- `POST /auth/refresh` if token refresh exists in the initial design

### Behavior
- register or upsert device record
- return device registration state
- return current environment/session metadata needed by the app

### Acceptance
- app Settings screen can display real registration/session values

---

## Phase R4: Push registration

### Objective
Allow the app to register an APNs token.

### Endpoints
- `POST /push/register`
- optional `DELETE /push/register/:deviceId`

### Behavior
- associate APNs token with device
- store environment metadata if needed
- support token refresh

### Acceptance
- app can submit its token and see server-confirmed registration state

---

## Phase R5: Inbox APIs

### Objective
Support asynchronous Hermes-to-user workflows.

### Endpoints
- `GET /inbox`
- `POST /inbox/:id/action`
- optional `POST /inbox` for internal/admin/Hermes-side creation if not done via internal service calls

### Behavior
- return pending and recent inbox items
- accept user actions such as approve, dismiss, open, confirm
- record results durably

### Acceptance
- inbox in the app can be backed by real data
- Hermes runtime can eventually consume results

---

## Phase R6: Chat transport

### Objective
Replace the mock Hermes client with real message transport.

### Endpoints
- `GET /conversations/:id`
- `POST /messages`

### Suggested first implementation
Start with straightforward request/response.
Only add SSE or WebSockets if needed after the basic app flow works.

### Behavior
- fetch current conversation state
- append user messages
- optionally enqueue Hermes processing or attach an immediate stubbed assistant response in early live phases

### Acceptance
- app chat is backed by durable relay state

---

## Phase R7: Realtime session issuance

### Objective
Support secure foreground Talk Mode without embedding provider root secrets in the app.

### Endpoint
- `POST /realtime/session`

### Behavior
- authenticate app/device
- create ephemeral session material or provider-ready session response
- return only the minimal client-safe session data needed to connect
- audit issuance if appropriate

### Acceptance
- live Talk Mode can request session credentials securely

---

## Phase R8: Capability request/result flows

### Objective
Create the first mobile tool mediation surfaces.

### Suggested endpoints
- `POST /capabilities/location/request`
- `POST /capabilities/location/result`
- `POST /capabilities/health/request`
- `POST /capabilities/health/result`
- `POST /uploads/media`

### Behavior
- create request records or inbox items
- accept structured results from the app
- expose result retrieval or event emission to Hermes runtime

### Acceptance
- relay can mediate at least one device capability flow end-to-end

---

## Phase R9: Hermes integration layer

### Objective
Give Hermes a clean way to create mobile actions and consume app results.

### Options
- internal service methods called by a colocated Hermes runtime integration
- webhook ingestion from Hermes runtime
- a small authenticated internal API used by Hermes tool wrappers

### Recommended first operations
- create inbox item
- send mobile message
- request location snapshot
- request health summary
- register voice session summary
- receive inbox action result

### Acceptance
- Hermes can trigger at least one user-visible action through the relay

---

## Phase R10: APNs sending

### Objective
Enable the relay to send visible or background notifications responsibly.

### Requirements
- APNs credentials/configuration
- notification category model
- send abstraction
- delivery logging

### Guardrails
- visible notifications for user attention
- background notifications only as sync hints
- respect Apple throttling realities

### Acceptance
- relay can send a visible inbox/action push to a registered test device

---

## Cross-cutting requirements
- Docker-first
- provider-neutral app logic
- env-based config
- structured logging
- basic audit trails for sensitive operations
- simple auth before complex auth
- no root provider keys in the iOS app

## Suggested build order
1. bootstrap service
2. database models
3. device registration
4. push registration
5. inbox APIs
6. chat transport
7. realtime session issuance
8. capability result flows
9. Hermes integration layer
10. APNs sending and refinement

## Recommended first proof-of-life demo
A minimal real demo should support:
- app registers device
- app fetches real session state
- app fetches real inbox items
- relay can create a visible inbox item and send push
- app displays the real inbox item

That proves the overall architecture without requiring the entire capability surface first.
