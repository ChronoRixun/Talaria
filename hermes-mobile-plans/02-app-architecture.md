# Hermes Mobile App and System Architecture

## Recommended System Shape

### 1. iOS App
Responsibilities:
- native UI
- foreground Talk Mode
- permission onboarding and transparency
- user-driven capability access
- local cache/persistence
- receiving pushes and showing inbox/actions
- foreground WebSocket / HTTP sync when active

### 2. Hermes Runtime
Responsibilities:
- long-running agent execution
- memory/tool orchestration
- task processing while app is closed
- asynchronous outbound messages and inbox actions

Important:
Hermes runtime should live outside the iOS process. Do not try to keep the full agent harness resident on-device as the durable source of truth.

### 3. Relay / Backend API
Responsibilities:
- user/device auth
- device registration
- APNs token registration
- event queue and inbox APIs
- media upload plumbing
- ephemeral OpenAI realtime credential/session issuance
- policy enforcement for device capability requests
- sync endpoints for the app
- Hermes-facing tool endpoints or event hooks

### 4. Data Layer
Recommended stores:
- Postgres for durable app/session/inbox records
- Redis or equivalent for transient events, throttling, or fanout if needed
- object storage for media uploads if media is included early

---

## Recommended Runtime Data Flow

### Text chat flow
1. App loads conversation from HermesClient service
2. Live service calls relay
3. Relay fetches or appends message to durable state
4. Hermes runtime may consume or respond asynchronously
5. Relay returns response or pushes follow-up via inbox/APNs

### Talk Mode flow
Preferred default:
1. App requests ephemeral realtime credentials from relay
2. App opens direct foreground realtime session to OpenAI
3. Tool or event handoff routes through relay/Hermes when needed
4. Relay logs session metadata and can post async follow-ups later

Why this is preferred:
- lower audio latency
- fewer moving parts in the critical voice path
- app never stores root provider keys

### Capability request flow
1. Hermes runtime wants device input or a snapshot
2. Relay creates an inbox item or request event
3. APNs notification alerts the user if needed
4. App opens, user approves or provides input
5. App gathers authorized data locally
6. App uploads structured result to relay
7. Hermes runtime consumes result

---

## Client-Side Architecture

### App layer
Suggested core types:
- `HermesMobileApp`
- `AppContainer`
- `AppSessionStore`
- `RootTabView`

### Feature layer
- Chat
- Talk
- Permissions
- Inbox
- Settings

### Services layer
- protocols first
- mock implementations now
- live implementations later

### Shared layer
- models
- reusable components
- theme/status helpers
- persistence wrappers

---

## ViewModel Guidance
Use one lightweight observable store or view model per major feature.

Examples:
- `ChatViewModel`
- `TalkModeViewModel`
- `PermissionsViewModel`
- `InboxViewModel`
- `SettingsViewModel`

Keep them:
- initializer-injected
- protocol-dependent
- async/await friendly
- small and screen-focused

---

## Live Service Upgrade Path

### Replace mock services with live implementations
- `LiveHermesClient`
- `LiveVoiceSessionService`
- `LiveLocationService`
- `LiveHealthService`
- `LiveNotificationService`
- `LiveMediaService`
- `LiveSyncCoordinator`
- `KeychainSecureStore`

### Relay-facing APIs likely needed
- `POST /device/register`
- `POST /auth/refresh`
- `GET /session`
- `GET /conversations/:id`
- `POST /messages`
- `GET /inbox`
- `POST /inbox/:id/action`
- `POST /push/register`
- `POST /realtime/session` or equivalent ephemeral issuance endpoint
- `POST /capabilities/location/snapshot/result`
- `POST /capabilities/health/summary/result`
- `POST /uploads`

---

## Provider / Deployment Recommendation
Best default for the relay depends on your priority:

### If you want lowest friction for always-on API + WebSockets
Recommend: Render or Fly.io

### If you want global edge fanout and lightweight event routing
Recommend: Cloudflare Workers + Durable Objects for specific connection-heavy workloads

### My practical recommendation for this product
Default recommendation:
- Fly.io if you want globally distributed, container-based relay services and private networking flexibility
- Render if you want simplest persistent web service deployment and the least operational friction

For this specific Hermes Mobile use case:
- Fly.io is strong if you expect WebSockets, multi-region presence, and private service topology
- Render is strong if you want a simpler “deploy a durable API + worker + Postgres” developer path
- Cloudflare is excellent for edge request handling and some realtime patterns, but is less ideal as the only home for a backend that also needs richer serverful agent/runtime adjacency

---

## iOS 26-era system integration notes
Relevant Apple platform guidance to design around:
- `BGContinuedProcessingTask` exists for user-initiated long-running work that may continue in the background, but it is not a generic always-on agent runtime
- background notifications are low-priority and not guaranteed; Apple advises against excessive frequency
- HealthKit observer queries plus background delivery require explicit entitlements and device testing
- Core Location background updates require explicit capabilities and clear user transparency
- App Intents and snippets create compelling system surfaces, but they are complements to the app, not a substitute for a durable backend

See `13-ios26-reference-notes.md` for details.
