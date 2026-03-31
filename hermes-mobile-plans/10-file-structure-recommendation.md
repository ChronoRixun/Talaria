# Hermes Mobile Recommended File Structure

This is a suggested layout, not a rigid requirement. Keep the structure lean.

```text
HermesMobile/
├── HermesMobileApp.swift
├── App/
│   ├── AppContainer.swift
│   ├── AppEnvironment.swift
│   ├── AppSessionStore.swift
│   └── RootTabView.swift
├── Shared/
│   ├── Models/
│   │   ├── Message.swift
│   │   ├── Conversation.swift
│   │   ├── HermesSessionState.swift
│   │   ├── VoiceSessionState.swift
│   │   ├── PermissionModels.swift
│   │   ├── InboxItem.swift
│   │   ├── UserSettings.swift
│   │   └── SyncStatus.swift
│   ├── Services/
│   │   ├── Protocols/
│   │   │   ├── HermesClientProtocol.swift
│   │   │   ├── VoiceSessionServiceProtocol.swift
│   │   │   ├── LocationServiceProtocol.swift
│   │   │   ├── HealthServiceProtocol.swift
│   │   │   ├── NotificationServiceProtocol.swift
│   │   │   ├── MediaServiceProtocol.swift
│   │   │   ├── SyncCoordinatorProtocol.swift
│   │   │   └── SecureStoreProtocol.swift
│   │   ├── Mocks/
│   │   │   ├── MockHermesClient.swift
│   │   │   ├── MockVoiceSessionService.swift
│   │   │   ├── MockLocationService.swift
│   │   │   ├── MockHealthService.swift
│   │   │   ├── MockNotificationService.swift
│   │   │   ├── MockMediaService.swift
│   │   │   ├── MockSyncCoordinator.swift
│   │   │   └── MockSecureStore.swift
│   │   └── Persistence/
│   │       ├── SettingsStore.swift
│   │       └── UserDefaultsSettingsStore.swift
│   ├── Components/
│   │   ├── StatusBadge.swift
│   │   ├── PermissionCard.swift
│   │   ├── MessageBubble.swift
│   │   ├── EmptyStateView.swift
│   │   └── SectionCard.swift
│   └── Theme/
│       └── AppTheme.swift
├── Features/
│   ├── Chat/
│   │   ├── ChatView.swift
│   │   ├── ChatViewModel.swift
│   │   └── ChatComposerView.swift
│   ├── Talk/
│   │   ├── TalkModeView.swift
│   │   ├── TalkModeViewModel.swift
│   │   └── VoiceVisualizerView.swift
│   ├── Permissions/
│   │   ├── PermissionsView.swift
│   │   └── PermissionsViewModel.swift
│   ├── Inbox/
│   │   ├── InboxView.swift
│   │   └── InboxViewModel.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
└── Preview Content/
    └── SampleData.swift
```

## Structural Guidance
- keep shared models central
- keep each feature small and self-contained
- do not create a file per micro-type unless it improves readability
- merge tiny related model files where practical
- if the actual generated structure differs slightly, preserve the same architectural intent
