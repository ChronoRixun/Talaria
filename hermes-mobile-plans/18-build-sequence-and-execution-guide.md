# Hermes Mobile Build Sequence and Execution Guide

## Purpose
This is the master step-by-step guide to hand to Claude Code or Codex along with the planning pack.

Before this file, the agent should read:
- `0-start-here.md`

It tells the implementation agent:
- what order to work in
- which planning docs to read at each stage
- what the deliverable is before moving on

Use this as the orchestration document for the full buildout.

---

## Overall execution philosophy
Do not try to build the entire system in one pass.
Use staged execution.
At each stage:
1. read only the relevant docs
2. inspect the current codebase first
3. make the smallest coherent set of changes
4. compile/test
5. summarize what remains blocked or mocked
6. move to the next stage only when the previous one is stable

---

## Stage 0: Planning and repo inspection

### Objective
Understand the generated frontend and align it to the planning pack before major coding.

### Read first
- `00-project-brief.md`
- `02-app-architecture.md`
- `10-file-structure-recommendation.md`
- `11-agent-handoff-prompt.md`
- `14-hermes-compatibility-and-tooling.md`

### Tasks
- inspect the current repo structure
- identify what already exists
- preserve good generated UI and models
- list divergences from the plan
- decide whether to refactor lightly or continue directly

### Exit criteria
- implementation agent understands current state
- no blind rewrite is planned

---

## Stage 1: Frontend MVP reconciliation and completion

### Objective
Finish the app shell and normalize the frontend architecture.

### Read
- `01-frontend-mvp-implementation-plan.md`
- `03-ui-ux-spec.md`
- `04-data-models-and-service-contracts.md`
- `05-permissions-capabilities.md`
- `06-voice-talk-mode-spec.md`
- `07-persistence-sync-notifications-spec.md`
- `09-testing-qa-checklist.md`

### Tasks
- normalize models and service protocols
- ensure mock services exist for all capabilities
- complete or improve Chat, Talk, Permissions, Inbox, Settings
- add lightweight persistence
- add previews and TODO seams
- compile and run locally

### Exit criteria
- frontend MVP is compileable and coherent
- no backend dependency required
- app is continuation-ready

---

## Stage 2: Integration seam validation

### Objective
Confirm the frontend is ready to accept live services without redesign.

### Read
- `08-backend-integration-seams.md`
- `14-hermes-compatibility-and-tooling.md`

### Tasks
- verify each mock service has a clean live replacement path
- add missing protocol or config seams if needed
- ensure views do not contain backend logic

### Exit criteria
- live services can be added behind protocols with minimal UI changes

---

## Stage 3: Relay architecture and deployment foundation

### Objective
Create the relay/backend project skeleton and deployment baseline.

### Read
- `12-provider-and-platform-research.md`
- `16-self-hosting-and-deployment-strategy.md`
- `17-relay-backend-implementation-plan.md`

### Tasks
- choose relay stack (FastAPI or Node/TypeScript)
- create provider-neutral relay service
- add Dockerfile and `.env.example`
- add local dev run path
- prepare Fly.io as official hosted target if desired
- prepare Docker Compose as self-host reference

### Exit criteria
- relay boots locally
- deployment strategy is not provider-locked

---

## Stage 4: Relay core APIs

### Objective
Implement the first live APIs the app actually needs.

### Read
- `17-relay-backend-implementation-plan.md`
- `02-app-architecture.md`
- `08-backend-integration-seams.md`

### Tasks
- device registration
- session bootstrap
- push registration
- inbox fetch/action APIs
- health/version endpoints

### Exit criteria
- app can connect to relay and display real session metadata and/or inbox data

---

## Stage 5: Live chat transport

### Objective
Replace mock Hermes chat transport with a real backend path.

### Read
- `17-relay-backend-implementation-plan.md`
- `04-data-models-and-service-contracts.md`
- `08-backend-integration-seams.md`

### Tasks
- implement conversation fetch
- implement send message
- update iOS live Hermes client
- preserve offline/mock fallback if useful for dev

### Exit criteria
- text chat persists through relay

---

## Stage 6: Push and inbox end-to-end

### Objective
Establish the async user-attention loop.

### Read
- `07-persistence-sync-notifications-spec.md`
- `13-ios26-reference-notes.md`
- `17-relay-backend-implementation-plan.md`

### Tasks
- APNs token registration in app
- APNs send path in relay
- notification routing to inbox or screen
- user action submission back to relay

### Exit criteria
- relay can notify device and the app can show/respond to the resulting inbox item

---

## Stage 7: Realtime Talk Mode live wiring

### Objective
Wire foreground Talk Mode to OpenAI Realtime safely.

### Read
- `06-voice-talk-mode-spec.md`
- `12-provider-and-platform-research.md`
- `13-ios26-reference-notes.md`
- `14-hermes-compatibility-and-tooling.md`
- `17-relay-backend-implementation-plan.md`

### Tasks
- implement relay endpoint for ephemeral session issuance
- implement live voice session service in app
- map realtime session states into Talk Mode UI
- ensure no root provider secret is shipped in app

### Exit criteria
- foreground voice session works live with backend-issued client-safe credentials

---

## Stage 8: Native capability live wiring

### Objective
Replace mock capability services with selective real integrations.

### Read
- `05-permissions-capabilities.md`
- `13-ios26-reference-notes.md`
- `08-backend-integration-seams.md`

### Recommended order
1. notifications
2. location snapshot and auth handling
3. camera/photos user-driven flow
4. health summary flow
5. canvas/drawing flow

### Exit criteria
- at least one real capability roundtrip works end to end through relay and app

---

## Stage 9: Background-safe sync and polish

### Objective
Make the app more resilient while respecting iOS constraints.

### Read
- `07-persistence-sync-notifications-spec.md`
- `13-ios26-reference-notes.md`
- `15-complete-buildout-roadmap.md`

### Tasks
- foreground resume sync
- background refresh hints where appropriate
- background URLSession for uploads if needed
- sync state cleanup
- inbox and session refresh strategy

### Exit criteria
- app behaves well even when background opportunities are delayed or sparse

---

## Stage 10: System integration surfaces

### Objective
Add higher-level iOS entry points if desired.

### Read
- `13-ios26-reference-notes.md`
- `15-complete-buildout-roadmap.md`

### Tasks
Possible additions:
- App Intents
- Shortcuts
- widgets
- Live Activities
- snippets where useful

### Exit criteria
- at least one meaningful system-level shortcut to Hermes exists

---

## Stage 11: Production hardening

### Objective
Prepare for real users.

### Read
- `09-testing-qa-checklist.md`
- `15-complete-buildout-roadmap.md`
- `16-self-hosting-and-deployment-strategy.md`

### Tasks
- auth/security review
- permission copy review
- logging and audit review
- reliability/reconnect review
- deployment documentation review
- self-hosting docs refinement

### Exit criteria
- hosted and self-host options are both coherent
- app and relay are production-shaped

---

## Recommended handoff batch strategy for Claude Code or Codex
If using an autonomous coding agent, run it in multiple sessions instead of one monolith.

Suggested sequence:
1. session A: inspect + reconcile frontend
2. session B: complete frontend MVP
3. session C: scaffold relay + deployment
4. session D: implement device/session/inbox APIs
5. session E: wire live chat
6. session F: wire push + inbox
7. session G: wire Talk Mode
8. session H: wire live capabilities
9. session I: polish and hardening

This tends to produce better results than a single giant prompt.

---

## Definition of planning completeness
The planning pack is complete enough for implementation when it provides:
- product vision
- architecture
- frontend MVP plan
- service contracts
- permissions/capabilities guidance
- background/push guidance
- provider/deployment strategy
- Hermes compatibility guidance
- backend relay plan
- execution order

This pack now satisfies those requirements.
