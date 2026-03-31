# Hermes Compatibility and Tooling Notes

## Goal
Make sure the app and backend are shaped so they work naturally with a Hermes-style agent framework and can be continued by Claude Code or Codex without architectural conflict.

## Key compatibility principle
Hermes works best when:
- durable state lives outside volatile UI processes
- tool boundaries are explicit
- async work can continue without the current chat or app being open
- mobile/device access is mediated through a clean API boundary

That means Hermes Mobile should not try to embed the full durable agent harness as the authoritative runtime inside the iOS app.

## Recommended compatibility shape

### iOS app role
- native client
- capability provider
- user-facing chat/voice/inbox shell
- device-authenticated endpoint

### Relay role
- stable API boundary between Hermes and the phone
- auth and policy mediator
- push and inbox coordinator
- ephemeral provider credential issuer

### Hermes role
- orchestrator
- memory/tool runner
- async actor
- creator of mobile requests, summaries, and follow-ups

---

## Hermes-facing operations the relay should expose
The backend should make it easy for Hermes to perform actions like:
- `send_mobile_message(userId, text, priority)`
- `create_inbox_item(userId, type, title, body, actions)`
- `request_location_snapshot(userId, reason)`
- `request_health_summary(userId, metrics, window)`
- `register_voice_session_summary(userId, sessionMetadata)`
- `record_user_action(userId, actionId, result)`
- `trigger_push(userId, category, payload)`

These can exist as:
- direct internal methods in the relay
- tool wrappers in Hermes that call relay HTTP endpoints
- webhook/event ingestion points

---

## Why this matches Hermes well
A Hermes-style system often needs to:
- send a message while the user is away
- request user input asynchronously
- wait for device-side results
- continue processing after a mobile event arrives

An inbox/event model is much more compatible with this than pretending the iOS app is a permanent live session.

---

## Recommended continuation strategy for Claude Code or Codex
When these agents take over the repo, they should:
1. inspect the generated Swift code first
2. preserve strong UI structure if present
3. normalize contracts, dependencies, and app container shape
4. add live services behind existing protocols
5. avoid moving too much logic into views
6. keep the relay API narrow and purpose-built

---

## Suggested backend implementation stack
A simple stack that fits Hermes well:
- FastAPI or Node/TypeScript service for relay API
- Postgres for durable app/session/inbox state
- Redis only if needed for fanout, rate limiting, or transient queues
- APNs provider integration
- object storage for media uploads

This stack works well because it is:
- easy for coding agents to extend
- explicit and inspectable
- friendly to both HTTP and async workers

---

## Realtime voice compatibility recommendation
Preferred approach:
- app gets ephemeral realtime credentials from relay
- app connects directly to OpenAI Realtime while in foreground
- Hermes receives tool/event callbacks through relay when relevant

This preserves:
- low-latency voice UX
- secret safety
- backend observability
- clean separation between voice transport and durable agent state

---

## Mobile tool philosophy
Hermes should not be granted “raw phone access.”
Instead, expose scoped, explicit mobile tools.

Examples:
- latest location summary
- request new location snapshot
- today’s step count summary
- request user photo review
- create reminder-style inbox request

This makes the system:
- safer
- easier to audit
- easier to reason about
- more App-Review-friendly

---

## Buildout implication
The repo should evolve toward two codebases or clearly separated modules:
1. Hermes Mobile iOS app
2. Hermes Mobile relay/backend

They should share:
- API contracts
- event types
- permission/capability semantics
- inbox/action schemas

But they should not collapse into a single on-device runtime assumption.
