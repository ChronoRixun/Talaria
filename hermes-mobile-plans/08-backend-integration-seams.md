# Hermes Mobile Backend Integration Seams

## Objective
Specify the exact seams to use when continuing from the frontend MVP into the full buildout.

## Rule
Views should never talk directly to backend details. Replace mock services with live implementations behind the existing protocols.

---

## Seam 1: Hermes chat transport
Current:
- seeded conversation
- local send flow
- simulated reply

Live replacement:
- conversation fetch
- send message
- message receipt reconciliation
- optional streaming updates

Protocol owner:
- `HermesClientProtocol`

Implementation notes:
- keep transport details out of `ChatView` and `ChatViewModel`
- consider HTTP for baseline chat, then add SSE/WebSocket if needed later

---

## Seam 2: Device registration and auth bootstrap
Current:
- placeholder connection status
- placeholder device identity

Live replacement:
- bootstrap session on launch
- register device if needed
- refresh tokens
- store tokens securely
- expose device registration state to Settings

Likely service owners:
- `SecureStoreProtocol`
- future `AuthServiceProtocol` or `DeviceRegistrationServiceProtocol` if the project needs them

Suggested endpoint family:
- `POST /device/register`
- `POST /auth/refresh`
- `GET /session`

---

## Seam 3: Push registration and inbox fetch
Current:
- placeholder push token status
- mock inbox items

Live replacement:
- APNs token registration
- fetch inbox items from relay
- submit inbox action results
- route visible notification opens to correct screen

Suggested endpoint family:
- `POST /push/register`
- `GET /inbox`
- `POST /inbox/:id/action`

---

## Seam 4: Realtime voice
Current:
- local UI states only

Live replacement:
- fetch ephemeral realtime credentials or session info from relay
- connect app to OpenAI Realtime for foreground voice
- hand off relevant tool/action events to Hermes relay when necessary
- persist session summary or follow-ups through backend

Protocol owner:
- `VoiceSessionServiceProtocol`

Suggested relay endpoint:
- `POST /realtime/session`

Important recommendation:
Prefer backend-issued ephemeral credentials with direct app-to-provider foreground realtime voice. Avoid shipping permanent provider secrets in the app.

---

## Seam 5: Native capability services
Current:
- mock statuses
- stub request actions

Live replacement:
- real authorization and limited data access
- structured result upload to relay
- user-mediated flows for camera/photos/canvas

Protocol owners:
- `LocationServiceProtocol`
- `HealthServiceProtocol`
- `NotificationServiceProtocol`
- `MediaServiceProtocol`

Suggested relay endpoint examples:
- `POST /capabilities/location/result`
- `POST /capabilities/health/result`
- `POST /uploads/media`

---

## Seam 6: Background sync
Current:
- placeholder sync status

Live replacement:
- reconcile app state with relay
- drain pending actions
- refresh inbox and conversation snapshots
- schedule appropriate background tasks

Protocol owner:
- `SyncCoordinatorProtocol`

---

## Seam 7: Hermes runtime compatibility layer
Current:
- none beyond mock architecture

Live replacement:
The backend should expose Hermes-friendly operations such as:
- send mobile message
- create inbox request
- request location snapshot
- request health summary
- notify user
- record capability result

This may be implemented as:
- internal service methods in the relay
- webhook-style event ingestion from Hermes
- direct Hermes tool wrappers calling relay endpoints

---

## Recommended continuation order
1. add config/env support and secure store
2. implement auth + device registration
3. implement live Hermes chat transport
4. implement APNs registration + inbox fetch/action flows
5. implement realtime voice ephemeral session flow
6. implement native capability services
7. implement background sync coordinator

## Acceptance criterion
A future coder should be able to continue from the current repo mostly by swapping concrete services and adding a few new live service types, not by redesigning the app structure.
