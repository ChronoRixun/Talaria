import Foundation
import UIKit

@MainActor
@Observable
final class AppSessionStore {
    private enum SecureKeys {
        static let accessToken = "session.accessToken"
        static let refreshToken = "session.refreshToken"
    }

    var state: AppSessionState {
        didSet { persistence.saveSessionState(state) }
    }
    var isBootstrapping = false
    var lastErrorMessage: String?

    private let bootstrapService: any SessionBootstrapServiceProtocol
    private let syncCoordinator: any SyncCoordinatorProtocol
    private let secureStore: any SecureStoreProtocol
    private let persistence: any AppPersistenceStoreProtocol
    private let notificationService: any NotificationServiceProtocol
    private let environmentProvider: @MainActor () -> AppEnvironment

    init(
        bootstrapService: any SessionBootstrapServiceProtocol,
        syncCoordinator: any SyncCoordinatorProtocol,
        secureStore: any SecureStoreProtocol,
        persistence: any AppPersistenceStoreProtocol,
        notificationService: any NotificationServiceProtocol,
        environmentProvider: @escaping @MainActor () -> AppEnvironment
    ) {
        self.bootstrapService = bootstrapService
        self.syncCoordinator = syncCoordinator
        self.secureStore = secureStore
        self.persistence = persistence
        self.notificationService = notificationService
        self.environmentProvider = environmentProvider
        self.state = persistence.loadSessionState() ?? AppSessionState()
    }

    func bootstrap(forceRegistration: Bool = false) async {
        guard !isBootstrapping else { return }

        isBootstrapping = true
        lastErrorMessage = nil
        state.connectionStatus = .connecting
        state.syncStatus = .syncing

        defer { isBootstrapping = false }

        let request = makeRegistrationRequest()

        do {
            if forceRegistration || !state.deviceRegistered || state.deviceID == nil {
                let response = try await bootstrapService.registerDevice(request)
                try await persist(tokens: response.tokens)
                state = mergeInstallationID(into: response.state, from: request.installationID)
            }

            let accessToken = await currentAccessToken()
            var loadedState = try await bootstrapService.loadSession(accessToken: accessToken)
            loadedState = mergeInstallationID(into: loadedState, from: request.installationID)
            loadedState.syncStatus = .synced
            loadedState.lastSyncAt = .now
            loadedState.pushTokenRegistered = notificationService.isPushTokenRegistered
            state = loadedState
        } catch {
            lastErrorMessage = error.localizedDescription
            state.connectionStatus = .error
            state.syncStatus = .error
        }
    }

    func refreshSession() async {
        await syncCoordinator.sync()
        state.syncStatus = .syncing
        await bootstrap(forceRegistration: false)
    }

    func currentAccessToken() async -> String? {
        await secureStore.retrieve(key: SecureKeys.accessToken)
    }

    func refreshAccessTokenIfNeeded() async {
        guard let refreshToken = await secureStore.retrieve(key: SecureKeys.refreshToken) else { return }

        do {
            let tokens = try await bootstrapService.refreshAuth(refreshToken: refreshToken)
            try await persist(tokens: tokens)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func persist(tokens: AuthTokens) async throws {
        await secureStore.store(key: SecureKeys.accessToken, value: tokens.accessToken)
        await secureStore.store(key: SecureKeys.refreshToken, value: tokens.refreshToken)
    }

    private func makeRegistrationRequest() -> DeviceRegistrationRequest {
        let device = UIDevice.current
        let bundle = Bundle.main

        return DeviceRegistrationRequest(
            installationID: state.installationID,
            deviceName: device.name,
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0",
            buildNumber: bundle.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "1",
            bundleID: bundle.bundleIdentifier ?? "com.appfactory.HermesMobile",
            deviceModel: device.model,
            systemVersion: device.systemVersion,
            environment: environmentProvider()
        )
    }

    private func mergeInstallationID(into state: AppSessionState, from installationID: UUID) -> AppSessionState {
        var mergedState = state
        mergedState.installationID = installationID
        return mergedState
    }
}
