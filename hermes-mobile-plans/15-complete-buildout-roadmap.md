# Hermes Mobile Complete Buildout Roadmap

This roadmap is intended for the continuation phase after the initial frontend shell exists.

## Stage 0: Reconcile the generated frontend
Objective:
- inspect what the first generator produced
- preserve good UI and file structure
- normalize architecture only where needed

Deliverables:
- compileable app
- cleaned dependency flow
- stable feature/view model separation
- minimal persistence

---

## Stage 1: Frontend MVP completion
Objective:
- finish any missing screens, previews, mock services, and TODO seams

Deliverables:
- Chat
- Talk Mode
- Permissions
- Inbox
- Settings
- polished runtime sample data

Exit criteria:
- passes `09-testing-qa-checklist.md`

---

## Stage 2: Relay foundation
Objective:
- stand up the first real backend relay

Suggested first endpoints:
- `POST /device/register`
- `POST /auth/refresh`
- `GET /session`
- `GET /inbox`
- `POST /push/register`
- `POST /realtime/session`

Suggested stack:
- Render or Fly.io
- Postgres
- simple service in FastAPI or Node/TypeScript

Exit criteria:
- app can register device and fetch session metadata

---

## Stage 3: Live chat transport
Objective:
- replace mock Hermes chat service with real transport

Suggested approach:
- start with HTTP request/response for fetch + send
- add SSE or WebSocket only if the product really benefits from it

Exit criteria:
- real messages persist across sessions
- app can fetch and send through relay

---

## Stage 4: Push + inbox
Objective:
- implement APNs token registration and real inbox items

Deliverables:
- token registration from app
- relay stores token per device
- visible notification flow
- inbox fetch and action submission

Exit criteria:
- Hermes/backend can create an inbox item and notify the user

---

## Stage 5: Realtime Talk Mode
Objective:
- wire foreground Talk Mode to OpenAI Realtime using ephemeral backend-issued credentials

Deliverables:
- relay endpoint that issues ephemeral session/token material
- voice service live implementation in app
- transcript and status mapping into Talk Mode UI
- summary or action handoff back to relay/Hermes

Exit criteria:
- user can start a live foreground voice session safely without bundling provider secrets in the app

---

## Stage 6: Capability services
Objective:
- replace mock location, health, notification, and media services with real native integrations

Suggested order:
1. notifications
2. location snapshot + permission handling
3. photos/camera user-driven flows
4. health summaries
5. canvas or PencilKit

Exit criteria:
- authorized device data can be gathered locally and returned to relay in structured form

---

## Stage 7: Background-safe sync
Objective:
- add practical sync behavior that respects iOS limits

Deliverables:
- foreground sync on launch and resume
- background refresh where appropriate
- visible and background push differentiation
- background URLSession for uploads if needed

Exit criteria:
- app remains coherent even when background opportunities are sparse or delayed

---

## Stage 8: System surfaces
Objective:
- deepen iOS integration beyond the main app UI

Candidates:
- App Intents
- Shortcuts
- widgets
- Live Activities
- optional snippets where useful

Exit criteria:
- at least one useful system-level quick action exists, such as opening Talk Mode or showing Hermes inbox

---

## Stage 9: Production hardening
Objective:
- harden privacy, auth, logging, reliability, and review-readiness

Deliverables:
- audit logging for capability requests
- privacy review of permission copy
- crash/error handling pass
- reconnection strategy for live services
- battery and background behavior validation on real devices

---

## Recommended execution sequence for coding agents
If handing to Claude Code or Codex, ask them to proceed in this order:
1. inspect and reconcile current frontend
2. complete frontend MVP gaps
3. add relay config + secure store
4. build relay foundation
5. wire live chat
6. wire APNs + inbox
7. wire Talk Mode
8. wire native capability services
9. add background-safe sync and polish

## Final architecture target
By the end, the project should feel like:
- a premium native Hermes companion app on iPhone
- a small durable relay service
- a clean integration boundary into Hermes runtime and tool execution
