import Foundation

@MainActor
@Observable
final class AppContainer {
    let router = TabRouter()
    let sessionStore: AppSessionStore
    let pairingStore: PairingStore
    let hostStore: HermesHostStore
    let chatStore: ChatStore
    let inboxStore: InboxStore
    let permissionsStore: PermissionsStore
    let settingsStore: SettingsStore
    let talkStore: TalkStore
    private var isInitialized = false

    init(
        sessionStore: AppSessionStore,
        pairingStore: PairingStore,
        hostStore: HermesHostStore,
        chatStore: ChatStore,
        inboxStore: InboxStore,
        permissionsStore: PermissionsStore,
        settingsStore: SettingsStore,
        talkStore: TalkStore
    ) {
        self.sessionStore = sessionStore
        self.pairingStore = pairingStore
        self.hostStore = hostStore
        self.chatStore = chatStore
        self.inboxStore = inboxStore
        self.permissionsStore = permissionsStore
        self.settingsStore = settingsStore
        self.talkStore = talkStore
    }

    static func makeDefault(
        defaults: UserDefaults? = nil,
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppContainer {
        let resolvedDefaults: UserDefaults
        if let defaults {
            resolvedDefaults = defaults
        } else if let suiteName = processEnvironment["UITEST_DEFAULTS_SUITE"] {
            resolvedDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        } else {
            resolvedDefaults = .standard
        }

        let persistence = UserDefaultsAppPersistenceStore(defaults: resolvedDefaults)
        let secureStore = KeychainSecureStore(
            serviceName: processEnvironment["UITEST_KEYCHAIN_SERVICE"] ?? "com.appfactory.HermesMobile.session"
        )
        let settingsStore = SettingsStore(persistence: persistence)
        let syncCoordinator = MockSyncCoordinator()
        let notificationService = MockNotificationService()
        let allowMockFallbacks = AppEnvironmentPolicy.currentBuild.allowsEnvironmentOverrides
        let usesMockPairingService = processEnvironment["UITEST_PAIRING_MODE"] == "mock"
        let pairingService: any PairingServiceProtocol
        var activePairingStore: PairingStore?

        if processEnvironment["UITEST_PAIRING_MODE"] == "mock" {
            pairingService = MockPairingService()
        } else {
            pairingService = LivePairingService()
        }

        let apiClient = RelayAPIClient {
            activePairingStore?.pairedRelayConfiguration?.baseURLString
                ?? settingsStore.settings.environment.baseURLString
        }

        let sessionBootstrapService = ResilientSessionBootstrapService(
            primary: LiveSessionBootstrapService(apiClient: apiClient),
            fallback: MockSessionBootstrapService(),
            allowsFallback: { allowMockFallbacks && (activePairingStore?.isPaired != true || usesMockPairingService) }
        )

        let inboxService = ResilientInboxService(
            primary: LiveInboxService(apiClient: apiClient),
            fallback: MockInboxService(),
            allowsFallback: { allowMockFallbacks && (activePairingStore?.isPaired != true || usesMockPairingService) }
        )

        let sessionStore = AppSessionStore(
            bootstrapService: sessionBootstrapService,
            syncCoordinator: syncCoordinator,
            secureStore: secureStore,
            persistence: persistence,
            notificationService: notificationService,
            environmentProvider: { settingsStore.settings.environment }
        )

        let runtimePairingStore = PairingStore(
            pairingService: pairingService,
            sessionStore: sessionStore,
            persistence: persistence,
            environmentProvider: { settingsStore.settings.environment }
        )
        activePairingStore = runtimePairingStore

        let hostService: any HermesHostServiceProtocol
        if usesMockPairingService {
            hostService = MockHermesHostService()
        } else {
            hostService = LiveHermesHostService(apiClient: apiClient)
        }

        let hostStore = HermesHostStore(
            hostService: hostService,
            accessTokenProvider: { await sessionStore.currentAccessToken() }
        )

        let hermesClient = ResilientHermesClient(
            primary: LiveHermesClient(
                apiClient: apiClient,
                accessTokenProvider: { await sessionStore.currentAccessToken() },
                allowDemoFallback: allowMockFallbacks && usesMockPairingService
            ),
            fallback: MockHermesClient(),
            allowsFallback: { allowMockFallbacks && (activePairingStore?.isPaired != true || usesMockPairingService) }
        )

        let container = AppContainer(
            sessionStore: sessionStore,
            pairingStore: runtimePairingStore,
            hostStore: hostStore,
            chatStore: ChatStore(hermesClient: hermesClient),
            inboxStore: InboxStore(
                inboxService: inboxService,
                persistence: persistence,
                sessionStore: sessionStore,
                allowDemoFallback: allowMockFallbacks
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
            guard container?.pairingStore.isPaired == false else { return }
            await sessionStore?.bootstrap(forceRegistration: true)
            await container?.inboxStore.loadInbox(force: true)
        }

        runtimePairingStore.onPairingChanged = { [weak container] isPaired in
            if isPaired {
                await container?.handlePairingActivated()
            } else {
                await container?.handlePairingRemoved()
            }
        }

        return container
    }

    func initialize() async {
        guard pairingStore.isPaired else { return }
        guard !isInitialized else { return }
        guard await sessionStore.currentAccessToken() != nil else {
            await pairingStore.clearLocalPairing()
            return
        }

        await permissionsStore.reloadCapabilities()
        await sessionStore.bootstrap()
        guard sessionStore.state.connectionStatus == .connected else { return }
        await hostStore.refresh()
        await chatStore.loadConversationIfNeeded()
        await inboxStore.loadInbox()
        isInitialized = true
    }

    private func handlePairingActivated() async {
        isInitialized = false
        chatStore.reset()
        inboxStore.reset()
        await initialize()
    }

    private func handlePairingRemoved() async {
        isInitialized = false
        router.selectedTab = .chat
        router.activeSheet = nil
        router.resetAll()
        chatStore.reset()
        inboxStore.reset()
        hostStore.reset()
    }
}
