# Blueprint: HermesMobile

## Product Summary
HermesMobile is a premium iOS companion app for a persistent Hermes AI agent. Phase 1 is a full-featured frontend shell with mocked services, designed for seamless backend wiring later. The visual identity is warm, cream/beige Liquid Glass — not cold or dark. Think premium consumer AI assistant, not developer tool.

## Core Features
1. **Conversation-first chat** — iMessage-like thread with glass user bubbles, plain Hermes responses with "H" avatar
2. **Talk Mode** — voice interaction with animated orb/waveform, state visualization (idle/listening/thinking/speaking/disconnected)
3. **Permissions management** — privacy-forward cards showing status, explanation, and action for each capability
4. **Actionable inbox** — approve/dismiss/open items from Hermes with status indicators
5. **Settings** — profile, connection, environment, notifications, privacy, about sections
6. **Capture placeholder** — camera/canvas stub with navigation seams for future expansion

## Target Audience
Power users who want a persistent AI assistant integrated into their daily life. Expects premium quality on par with Cal AI or Opal.

## Architecture

### Pattern: MV (Model-View)
- No view models. Views are thin orchestration layers.
- `@Observable` services hold business logic and state.
- `@State` for local view state, `@Environment` for shared dependencies.
- One type per file. Strict file ordering convention.

### Navigation Graph
```
TabView (4 tabs)
├── Chat (primary tab)
│   ├── ChatScreen (root)
│   │   ├── [push] ConversationListSheet (hamburger menu)
│   │   └── [push] NewConversationSheet (compose button)
│   └── [push] CaptureScreen (from attachment/pen icon)
├── Talk
│   └── TalkModeScreen (root)
├── Inbox
│   └── InboxScreen (root)
│       └── [sheet] InboxItemDetailSheet
└── Settings
    └── SettingsScreen (root)
        └── [push] PermissionsScreen
```

### Tab Configuration
| Tab | Title | Icon | Root Screen |
|-----|-------|------|-------------|
| chat | Chat | bubble.left.and.bubble.right | ChatScreen |
| talk | Talk | waveform.circle | TalkModeScreen |
| inbox | Inbox | tray.full | InboxScreen |
| settings | Settings | gearshape | SettingsScreen |

## Data Model

### Models (10 types)
| Model | Type | Description |
|-------|------|-------------|
| Message | struct | Chat message with sender, content, timestamp, status |
| Conversation | struct | Thread container with messages, title, last activity |
| MessageSender | enum | .user, .hermes, .system |
| MessageStatus | enum | .sending, .sent, .delivered, .failed |
| VoiceState | enum | .idle, .listening, .thinking, .speaking, .disconnected |
| PermissionType | enum | .location, .health, .notifications, .camera, .photos |
| PermissionStatus | enum | .notDetermined, .authorized, .denied, .restricted |
| InboxItem | struct | Actionable item with type, title, body, actions, timestamp |
| InboxItemType | enum | .approval, .notification, .reminder, .suggestion, .alert |
| ConnectionStatus | enum | .connected, .connecting, .disconnected, .error |
| UserSettings | struct | User preferences (name, notifications, privacy, etc.) |
| SyncStatus | enum | .synced, .syncing, .offline, .error |
| DeviceCapability | struct | Device capability description and authorization |

### Service Protocols (8 protocols)
| Protocol | Mock Implementation | Purpose |
|----------|-------------------|---------|
| HermesClientProtocol | MockHermesClient | Chat send/receive, connection status |
| VoiceSessionServiceProtocol | MockVoiceSessionService | Voice state, transcript, session management |
| LocationServiceProtocol | MockLocationService | Location authorization, current location |
| HealthServiceProtocol | MockHealthService | HealthKit authorization, sample data |
| NotificationServiceProtocol | MockNotificationService | Push auth, local notifications |
| MediaServiceProtocol | MockMediaService | Camera/photo auth, capture |
| SyncCoordinatorProtocol | MockSyncCoordinator | Sync status across services |
| SecureStoreProtocol | MockSecureStore | Keychain-like settings/credential storage |

## File Structure
```
HermesMobile/
├── AppEntry.swift
├── Core/
│   ├── Design.swift
│   ├── Router.swift
│   └── Extensions/
│       └── View+Glass.swift
├── Models/
│   ├── Message.swift
│   ├── Conversation.swift
│   ├── MessageSender.swift
│   ├── MessageStatus.swift
│   ├── VoiceState.swift
│   ├── PermissionType.swift
│   ├── PermissionStatus.swift
│   ├── InboxItem.swift
│   ├── InboxItemType.swift
│   ├── ConnectionStatus.swift
│   ├── UserSettings.swift
│   ├── SyncStatus.swift
│   └── DeviceCapability.swift
├── Services/
│   ├── Protocols/
│   │   ├── HermesClientProtocol.swift
│   │   ├── VoiceSessionServiceProtocol.swift
│   │   ├── LocationServiceProtocol.swift
│   │   ├── HealthServiceProtocol.swift
│   │   ├── NotificationServiceProtocol.swift
│   │   ├── MediaServiceProtocol.swift
│   │   ├── SyncCoordinatorProtocol.swift
│   │   └── SecureStoreProtocol.swift
│   └── Mocks/
│       ├── MockHermesClient.swift
│       ├── MockVoiceSessionService.swift
│       ├── MockLocationService.swift
│       ├── MockHealthService.swift
│       ├── MockNotificationService.swift
│       ├── MockMediaService.swift
│       ├── MockSyncCoordinator.swift
│       └── MockSecureStore.swift
├── Features/
│   ├── Chat/
│   │   ├── ChatScreen.swift
│   │   ├── MessageBubble.swift
│   │   ├── ChatInputBar.swift
│   │   └── HermesAvatar.swift
│   ├── Talk/
│   │   ├── TalkModeScreen.swift
│   │   ├── VoiceOrb.swift
│   │   └── TranscriptView.swift
│   ├── Inbox/
│   │   ├── InboxScreen.swift
│   │   └── InboxItemRow.swift
│   ├── Settings/
│   │   ├── SettingsScreen.swift
│   │   └── SettingsSectionView.swift
│   ├── Permissions/
│   │   ├── PermissionsScreen.swift
│   │   └── PermissionCard.swift
│   └── Capture/
│       └── CaptureScreen.swift
├── Components/
│   ├── GlassCircleButton.swift
│   ├── StatusIndicator.swift
│   └── DemoData.swift
└── Resources/
    ├── Assets.xcassets/
    └── Info.plist
```

## Visual Identity Map

| Enum | Case | Color | Icon | Label |
|------|------|-------|------|-------|
| PermissionType | .location | .blue | "location.fill" | "Location" |
| PermissionType | .health | .red | "heart.fill" | "Health" |
| PermissionType | .notifications | .orange | "bell.fill" | "Notifications" |
| PermissionType | .camera | .purple | "camera.fill" | "Camera" |
| PermissionType | .photos | .green | "photo.fill" | "Photos" |
| InboxItemType | .approval | .orange | "checkmark.seal.fill" | "Approval" |
| InboxItemType | .notification | .blue | "bell.badge.fill" | "Notification" |
| InboxItemType | .reminder | .purple | "clock.fill" | "Reminder" |
| InboxItemType | .suggestion | .teal | "lightbulb.fill" | "Suggestion" |
| InboxItemType | .alert | .red | "exclamationmark.triangle.fill" | "Alert" |
| ConnectionStatus | .connected | .green | "checkmark.circle.fill" | "Connected" |
| ConnectionStatus | .connecting | .orange | "arrow.triangle.2.circlepath" | "Connecting" |
| ConnectionStatus | .disconnected | .secondary | "xmark.circle.fill" | "Disconnected" |
| ConnectionStatus | .error | .red | "exclamationmark.circle.fill" | "Error" |
| VoiceState | .idle | .secondary | "mic.slash" | "Ready" |
| VoiceState | .listening | .blue | "mic.fill" | "Listening" |
| VoiceState | .thinking | .purple | "brain" | "Thinking" |
| VoiceState | .speaking | .green | "speaker.wave.2.fill" | "Speaking" |
| VoiceState | .disconnected | .red | "wifi.slash" | "Disconnected" |

## Design Direction

### Color Palette
- **Background:** Warm cream/off-white (#FAF7F2 light, rich dark brown/charcoal dark)
- **Brand accent:** Warm gold/amber for subtle highlights
- **Glass tint:** None (let warm background show through glass)
- **User bubbles:** Frosted glass with warm cream tint
- **Hermes text:** Primary foreground, no bubble
- **Hermes avatar:** Small circle with "H", subtle glass or brand tint

### Typography
- Screen titles: `.title.bold()` or `.title2.bold()`
- "Hermes Agent" header: Semi-bold, centered
- Message text: `.body`
- Timestamps: `.caption`, secondary color
- Input placeholder: `.body`, tertiary color

### Interaction
- All glass buttons use spring animations
- Input bar has glass pill shape
- Tab bar uses `.tabBarMinimizeBehavior(.onScrollDown)` for immersive chat scrolling
- Voice orb pulses with spring physics

## P2 Features (Not building)
- Real WebSocket transport
- Real OpenAI Realtime Session integration
- Full HealthKit data pipeline
- Production location tracking
- Push notification backend
- Analytics/logging
- Account authentication
- Canvas/capture full implementation (placeholder only)

## Integration Seams
Each service protocol defines the contract for future backend wiring:
- `HermesClientProtocol.connect()` / `.send()` / `.disconnect()` — replace mock with WebSocket
- `VoiceSessionServiceProtocol.startSession()` / `.endSession()` — replace with OpenAI Realtime
- Location/Health/Notification/Media protocols — replace mocks with real framework calls
- `SecureStoreProtocol` — replace with Keychain wrapper
- `SyncCoordinatorProtocol` — replace with server sync engine
