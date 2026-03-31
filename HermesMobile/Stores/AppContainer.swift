import Foundation

@MainActor
@Observable
final class AppContainer {
    let router = TabRouter()
    let sessionStore: AppSessionStore
    let chatStore: ChatStore
    let inboxStore: InboxStore
    let permissionsStore: PermissionsStore
    let settingsStore: SettingsStore
    let talkStore: TalkStore

    init(
        sessionStore: AppSessionStore,
        chatStore: ChatStore,
        inboxStore: InboxStore,
        permissionsStore: PermissionsStore,
        settingsStore: SettingsStore,
        talkStore: TalkStore
    ) {
        self.sessionStore = sessionStore
        self.chatStore = chatStore
        self.inboxStore = inboxStore
        self.permissionsStore = permissionsStore
        self.settingsStore = settingsStore
        self.talkStore = talkStore
    }

    static func makeDefault(defaults: UserDefaults = .standard) -> AppContainer {
        let persistence = UserDefaultsAppPersistenceStore(defaults: defaults)
        let secureStore = MockSecureStore()
        let settingsStore = SettingsStore(persistence: persistence)
        let syncCoordinator = MockSyncCoordinator()
        let notificationService = MockNotificationService()

        let apiClient = RelayAPIClient {
            settingsStore.settings.environment.baseURLString
        }

        let sessionBootstrapService = ResilientSessionBootstrapService(
            primary: LiveSessionBootstrapService(apiClient: apiClient),
            fallback: MockSessionBootstrapService()
        )

        let inboxService = ResilientInboxService(
            primary: LiveInboxService(apiClient: apiClient),
            fallback: MockInboxService()
        )

        let sessionStore = AppSessionStore(
            bootstrapService: sessionBootstrapService,
            syncCoordinator: syncCoordinator,
            secureStore: secureStore,
            persistence: persistence,
            notificationService: notificationService,
            environmentProvider: { settingsStore.settings.environment }
        )

        let hermesClient = ResilientHermesClient(
            primary: LiveHermesClient(
                apiClient: apiClient,
                accessTokenProvider: { await sessionStore.currentAccessToken() }
            ),
            fallback: MockHermesClient()
        )

        let container = AppContainer(
            sessionStore: sessionStore,
            chatStore: ChatStore(hermesClient: hermesClient),
            inboxStore: InboxStore(
                inboxService: inboxService,
                persistence: persistence,
                sessionStore: sessionStore
            ),
            permissionsStore: PermissionsStore(
                locationService: MockLocationService(),
                healthService: MockHealthService(),
                notificationService: notificationService,
                mediaService: MockMediaService()
            ),
            settingsStore: settingsStore,
            talkStore: TalkStore(voiceService: MockVoiceSessionService())
        )

        settingsStore.onEnvironmentChanged = { [weak sessionStore, weak container] _ in
            await sessionStore?.bootstrap(forceRegistration: true)
            await container?.inboxStore.loadInbox(force: true)
        }

        return container
    }

    func initialize() async {
        await permissionsStore.reloadCapabilities()
        await sessionStore.bootstrap()
        await chatStore.loadConversationIfNeeded()
        await inboxStore.loadInbox()
    }
}
