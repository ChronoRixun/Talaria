# Hermes Mobile Data Models and Service Contracts

## Core Models

### Message
Suggested fields:
- `id`
- `conversationID`
- `role` (`user`, `hermes`, `system` if needed)
- `text`
- `timestamp`
- `deliveryState` (local/mock if useful)
- `attachments` (optional placeholder)

### Conversation
Suggested fields:
- `id`
- `title`
- `messages`
- `updatedAt`
- `isMock`

### HermesSessionState
Suggested fields:
- `connectionStatus`
- `isMockMode`
- `deviceRegistered`
- `lastSyncAt`
- `backendEndpoint` (placeholder)

### VoiceSessionState
Suggested fields:
- `status` (`idle`, `listening`, `thinking`, `speaking`, `disconnected`)
- `isMuted`
- `transcriptPreview`
- `startedAt`
- `elapsedSeconds`

### PermissionType
Enum cases:
- `location`
- `health`
- `notifications`
- `camera`
- `photos`

### PermissionStatus
Enum suggestions:
- `notDetermined`
- `authorized`
- `limited`
- `denied`
- `restricted`
- `unsupported`

### PermissionItem
Suggested fields:
- `type`
- `title`
- `description`
- `status`
- `canRequest`

### InboxItem
Suggested fields:
- `id`
- `kind`
- `title`
- `body`
- `createdAt`
- `priority`
- `status`
- `primaryActionTitle`
- `secondaryActionTitle`

### DeviceCapability
Can be a lightweight enum or struct describing major app capability groups.

### UserSettings
Suggested fields:
- `displayName`
- `preferredEnvironment`
- `notificationsEnabled`
- `showDebugInfo`
- `autoPlayVoiceResponses` (future-facing but acceptable)

### SyncStatus
Suggested fields:
- `state` (`idle`, `syncing`, `success`, `error`, `offline`)
- `lastSyncAt`
- `detailText`

### ConnectionStatus
Suggested enum:
- `offline`
- `mockLocal`
- `connectingSoon`
- `connected` (future)

---

## Service Protocols

### HermesClientProtocol
Responsibilities:
- load seeded/mock conversation
- send a message
- optionally simulate a Hermes reply
- expose connection/session state

Suggested methods:
- `func loadConversation() async throws -> Conversation`
- `func sendMessage(_ text: String) async throws -> Message`
- `func fetchSessionState() async -> HermesSessionState`

### VoiceSessionServiceProtocol
Responsibilities:
- manage Talk Mode UI state
- start/stop session
- mute/unmute
- simulate transcript updates

Suggested methods:
- `func currentState() -> VoiceSessionState`
- `func startSession() async`
- `func stopSession() async`
- `func toggleMute() async`
- `func setMockStatus(_ status: VoiceStatus) async`

### LocationServiceProtocol
Responsibilities:
- expose authorization state
- future location snapshot entry point

Suggested methods:
- `func authorizationStatus() async -> PermissionStatus`
- `func requestPermission() async -> PermissionStatus`
- `func latestLocationSummary() async -> String?`

### HealthServiceProtocol
Responsibilities:
- expose authorization state
- future health summary seam

Suggested methods:
- `func authorizationStatus() async -> PermissionStatus`
- `func requestPermission() async -> PermissionStatus`
- `func latestHealthSummary() async -> String?`

### NotificationServiceProtocol
Responsibilities:
- expose notification auth status
- future push registration seam

Suggested methods:
- `func authorizationStatus() async -> PermissionStatus`
- `func requestPermission() async -> PermissionStatus`
- `func pushTokenStatus() async -> String`

### MediaServiceProtocol
Responsibilities:
- cover camera/photos/canvas placeholder workflows

Suggested methods:
- `func cameraAuthorizationStatus() async -> PermissionStatus`
- `func photosAuthorizationStatus() async -> PermissionStatus`
- `func requestCameraPermission() async -> PermissionStatus`
- `func requestPhotosPermission() async -> PermissionStatus`

### SyncCoordinatorProtocol
Responsibilities:
- expose sync state only for MVP
- later orchestrate background sync

Suggested methods:
- `func currentStatus() async -> SyncStatus`
- `func triggerManualRefresh() async`

### SecureStoreProtocol
Responsibilities:
- future token/key storage
- no real secrets required in MVP

Suggested methods:
- `func set(_ value: String, for key: String) throws`
- `func value(for key: String) throws -> String?`
- `func removeValue(for key: String) throws`

---

## Mocking Guidance
Every service should have a mock implementation with:
- deterministic starter data
- lightweight local mutability
- no hidden network logic
- preview-friendly constructors if helpful

## Integration Guidance
Do not place networking code directly into views.
When live backend work starts, replace mock services with live implementations behind the same protocols.
