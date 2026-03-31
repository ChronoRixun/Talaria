# Build Summary: HermesMobile

## What Was Built

A complete iOS 26+ companion app for a persistent Hermes AI agent. 6 screens, all with full Liquid Glass styling, warm cream/beige design, and mock data that feels real.

### Screens (6)
1. **ChatScreen** — Conversation-first messaging with glass user bubbles, "H" avatar for Hermes messages, glass input bar (pen icon, text field, send arrow), glass circle navigation buttons (hamburger for conversations, compose for new), connection status indicator in toolbar
2. **TalkModeScreen** — Voice orb with physics-based pulse animations that respond to state (idle/listening/thinking/speaking/disconnected), transcript area, session timer, mute and end controls in a glass effect container, mock mode indicator
3. **InboxScreen** — Scrollable list of actionable items with type-colored icons (approval=orange, notification=blue, reminder=purple, suggestion=teal, alert=red), approve/dismiss buttons, unread indicators, empty state with ContentUnavailableView
4. **SettingsScreen** — Grouped sections (Profile, Connection, Environment, Notifications, Privacy, About) with glass card surfaces, toggles with warm gold tint, environment selector, permission navigation
5. **PermissionsScreen** — Cards for each capability (Location, Health, Notifications, Camera, Photos) with colored icons, explanation text, current status, and action buttons
6. **CaptureScreen** — Placeholder with ContentUnavailableView and navigation seam back to chat

### Components (10)
- GlassCircleButton, StatusIndicator, HermesAvatar, MessageBubble, ChatInputBar, VoiceOrb, TranscriptView, InboxItemRow, InboxItemDetailSheet, SettingsSectionView, PermissionCard

### Models (13)
- Message, Conversation, MessageSender, MessageStatus, VoiceState, PermissionType, PermissionStatus, InboxItem, InboxItemType, ConnectionStatus, UserSettings, SyncStatus, DeviceCapability

### Services (8 protocols + 8 mocks)
- HermesClientProtocol, VoiceSessionServiceProtocol, LocationServiceProtocol, HealthServiceProtocol, NotificationServiceProtocol, MediaServiceProtocol, SyncCoordinatorProtocol, SecureStoreProtocol

## Architecture Decisions

1. **MV pattern** — No view models. Views are thin. Services hold business logic via @Observable.
2. **@MainActor protocols** — All service protocols are @MainActor isolated. This matches the mock implementations (which are @Observable + @MainActor) and avoids Swift 6.2 strict concurrency errors. When wiring real backends, the protocols may need adjustment.
3. **nonisolated enum DemoData** — Static demo data in a plain enum, not an @Observable service. Avoids unnecessary actor isolation.
4. **Per-tab NavigationPath** — Each tab owns its own navigation path through TabRouter. No cross-tab navigation pollution.
5. **Warm background via ZStack** — Each screen uses `Design.Brand.backgroundPrimary` as a background color behind its content. This gives the warm cream tone that shows through glass effects.

## Design Decisions

1. **Warm cream/beige palette** — backgroundPrimary is Color(red: 0.98, green: 0.97, blue: 0.94). Deliberately warm, not the cold system white.
2. **Gold accent** — Brand.warmGold (Color(red: 0.82, green: 0.68, blue: 0.42)) used for the "H" avatar, send button, toggle tints, and checkmarks. Creates a premium, warm feel.
3. **Glass on content, not background** — Glass effects on elevated surfaces (user message bubbles, input bar, inbox cards, settings sections, permission cards, toolbar buttons). Background stays warm and opaque.
4. **User bubbles glass, Hermes plain text** — Asymmetric design: user messages get frosted glass bubbles, Hermes responses are clean left-aligned text with an "H" avatar circle. Matches the reference screenshot direction.
5. **Spring animations throughout** — All interactive state changes use spring physics. Voice orb pulses with breathing animations. Transitions use .combined(with:) for polish.

## Known Limitations

- **Simulator preflight issue** — The Xcode 26 beta simulator has a known issue where apps fail preflight checks, preventing test execution. The code compiles and the tests are valid.
- **No real backend** — All services are mocked. Chat responses are random from a pool. Voice mode cycles through states on a timer.
- **No persistence** — Messages and settings are in-memory only. Closing the app resets state.
- **Conversation list sheet** — Shows placeholder text, not a real conversation list.
- **New conversation sheet** — Shows placeholder text, not a real creation flow.
- **Capture screen** — Placeholder only, no camera integration.

## Integration Seams for Future Backend

Each service protocol defines the contract. Replace mock implementations with:
- `MockHermesClient` -> WebSocket-backed client implementing `HermesClientProtocol`
- `MockVoiceSessionService` -> OpenAI Realtime Session implementing `VoiceSessionServiceProtocol`
- `MockLocationService` -> CLLocationManager wrapper implementing `LocationServiceProtocol`
- `MockHealthService` -> HealthKit query engine implementing `HealthServiceProtocol`
- `MockNotificationService` -> UNUserNotificationCenter wrapper implementing `NotificationServiceProtocol`
- `MockMediaService` -> AVCaptureSession + PHPhotoLibrary implementing `MediaServiceProtocol`
- `MockSyncCoordinator` -> Server sync engine implementing `SyncCoordinatorProtocol`
- `MockSecureStore` -> Keychain wrapper implementing `SecureStoreProtocol`

## P2 Features Not Built
- Real WebSocket transport
- OpenAI Realtime voice session
- Full HealthKit integration
- Production location pipeline
- Push notification backend
- Camera/canvas full implementation
- Conversation history and search
- Account authentication
