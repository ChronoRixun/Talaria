# Hermes Mobile Frontend MVP Implementation Plan

> Primary execution plan for Claude Code or Codex while the current generator run produces the baseline app.

## Goal
Deliver a compileable, polished SwiftUI frontend MVP that can immediately continue into live backend integration without structural rework.

## Outcome Required
At the end of this phase the project should have:
- a real app shell
- clear feature folders
- shared domain models
- protocol-based service layer
- mock implementations for all external dependencies
- persistence for at least settings and environment state
- polished core screens and previews
- explicit TODO seams for Hermes/backend continuation

## Architectural Guardrails
- SwiftUI first
- no business logic in views
- protocols at service boundaries
- one explicit dependency container
- simple persistence now, upgradeable later
- no speculative networking stack
- no overbuilt reducer or repository architecture unless clearly justified by generated code structure

## Continuation Guardrails
The code written now must make these future additions easy:
- device registration
- auth/bootstrap
- Hermes chat transport
- OpenAI Realtime Talk Mode
- APNs registration and inbox fetch
- capability-backed native services
- background refresh coordination

---

## Milestone A: Project bootstrap

### A1. Create or normalize project structure
Ensure the codebase has predictable folders matching the recommended structure doc.

### A2. Add root container and app session store
Create a single dependency container that provides protocol-backed services.

### A3. Add app-level state
Track:
- selected environment
- connection status
- sync status
- current settings snapshot

Acceptance:
- app launches into the root shell
- all tabs are reachable

---

## Milestone B: Shared domain and contracts

### B1. Add shared models
Required:
- Message
- Conversation
- HermesSessionState
- VoiceSessionState
- PermissionType
- PermissionStatus
- PermissionItem
- InboxItem
- DeviceCapability
- UserSettings
- SyncStatus
- ConnectionStatus

### B2. Add service protocols
Required:
- HermesClientProtocol
- VoiceSessionServiceProtocol
- LocationServiceProtocol
- HealthServiceProtocol
- NotificationServiceProtocol
- MediaServiceProtocol
- SyncCoordinatorProtocol
- SecureStoreProtocol
- optional SettingsStoreProtocol if persistence is abstracted

Acceptance:
- screens and view models compile against contracts only

---

## Milestone C: Mock implementations

### C1. Mock Hermes client
Needs to support:
- seeded conversation
- local message append
- simulated delayed Hermes reply
- mock connection status

### C2. Mock Talk Mode service
Needs to support:
- state transitions
- transcript preview updates
- mute state
- optional timer

### C3. Mock capability services
Needs to support:
- current permission state
- request/update behavior
- safe no-op open-settings hook
- placeholder summaries for location and health

### C4. Mock sync + secure store
Needs to support:
- fake sync status updates
- placeholder token/status values

Acceptance:
- the entire app works without network or secrets

---

## Milestone D: Chat feature

### D1. Chat view model
Own:
- conversation state
- composer text
- send flow
- loading/error state

### D2. Chat screen
Must include:
- header/title
- connection badge or status strip
- message thread
- polished composer
- Talk Mode entry
- attachment affordance placeholder

### D3. Message components
Create reusable message bubble and status components.

Acceptance:
- send flow is immediate and stable
- mock replies appear coherently
- empty/loading/populated states exist where useful

---

## Milestone E: Talk Mode feature

### E1. Talk view model
Own:
- current voice status
- timer
- transcript preview
- mute state

### E2. Talk screen
Must include:
- immersive central visual
- state label
- transcript preview
- mute and end controls
- mock mode indicator

Acceptance:
- all main voice states are demoable
- layout feels premium in light/dark mode

---

## Milestone F: Permissions feature

### F1. Permissions view model
Aggregate statuses from location, health, notifications, and media services.

### F2. Permissions screen
Must render cards or rows for:
- Location
- Health
- Notifications
- Camera
- Photos

Acceptance:
- copy is privacy-forward
- actions are safe
- denied / limited / not requested states all render correctly

---

## Milestone G: Inbox feature

### G1. Inbox model behaviors
Support simple state mutation for actions like approve, dismiss, open.

### G2. Inbox screen
Render mock pending Hermes requests with action buttons and timestamps.

Acceptance:
- state changes are local and believable
- empty state looks intentional

---

## Milestone H: Settings feature

### H1. Settings persistence
Persist at minimum:
- display name if editable
- preferred environment
- notifications preference toggle
- show debug info toggle

### H2. Settings screen
Must include:
- profile/device section
- connection/sync section
- privacy/permissions entry
- notifications section
- local data/debug section
- about/version section

### H3. Connection placeholders
Show future-facing values for:
- device registered
- last sync time
- push token status
- backend endpoint

Acceptance:
- at least one setting survives relaunch

---

## Milestone I: polish and continuation prep

### I1. Previews
Add previews for major screens and at least some alternate states.

### I2. TODO seams
Add targeted TODO comments where live services will replace mock behavior.

### I3. Light QA pass
Validate against `09-testing-qa-checklist.md`.

### I4. Continuation note in code
Document where phase 2 should begin:
- HermesClient live implementation
- auth/device registration service
- APNs service
- realtime voice session service

Acceptance:
- another coding agent can continue directly from the repo without needing a redesign pass

---

## Immediate Follow-On After MVP
Once the shell is stable, the next implementation pass should:
1. add a backend config object and environments
2. implement secure token storage
3. add device registration and auth bootstrap
4. replace mock Hermes chat with live HTTP/WebSocket/SSE-backed transport as chosen
5. add APNs token registration and inbox sync
6. add ephemeral key/session flow for OpenAI Realtime Talk Mode

## Definition of Done
- app compiles and runs on device/simulator without secrets
- screens feel like a real product shell
- settings persist minimally
- all external dependencies are abstracted behind protocols
- the repo is continuation-ready for the full buildout roadmap
