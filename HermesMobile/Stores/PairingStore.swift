import Foundation

@MainActor
@Observable
final class PairingStore {
    var pairedRelayConfiguration: PairedRelayConfiguration?
    var isWorking = false
    var lastErrorMessage: String?
    var onPairingChanged: (@MainActor (Bool) async -> Void)?

    private let pairingService: any PairingServiceProtocol
    private let sessionStore: AppSessionStore
    private let persistence: any AppPersistenceStoreProtocol
    private let environmentProvider: @MainActor () -> AppEnvironment

    init(
        pairingService: any PairingServiceProtocol,
        sessionStore: AppSessionStore,
        persistence: any AppPersistenceStoreProtocol,
        environmentProvider: @escaping @MainActor () -> AppEnvironment
    ) {
        self.pairingService = pairingService
        self.sessionStore = sessionStore
        self.persistence = persistence
        self.environmentProvider = environmentProvider
        self.pairedRelayConfiguration = persistence.loadPairedRelayConfiguration()
    }

    var isPaired: Bool {
        pairedRelayConfiguration != nil
    }

    func decodeSetupCode(_ rawCode: String) throws -> RelaySetupCodePayload {
        try pairingService.decodeSetupCode(rawCode)
    }

    @discardableResult
    func pair(using rawSetupCode: String, displayName: String) async -> Bool {
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDisplayName.isEmpty else {
            lastErrorMessage = "Enter a display name to continue."
            return false
        }

        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }

        do {
            let payload = try pairingService.decodeSetupCode(rawSetupCode)
            let request = DeviceRegistrationRequest.current(
                installationID: sessionStore.state.installationID,
                environment: environmentProvider()
            )
            let result = try await pairingService.redeemSetupCode(
                payload: payload,
                displayName: trimmedDisplayName,
                request: request
            )

            persistence.savePairedRelayConfiguration(result.configuration)
            pairedRelayConfiguration = result.configuration
            lastErrorMessage = nil
            await sessionStore.applyPairedSession(state: result.state, tokens: result.tokens)
            await onPairingChanged?(true)
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    func disconnect() async {
        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }

        await sessionStore.revokeCurrentSession()
        await clearLocalPairing(notify: true)
    }

    func clearLocalPairing(notify: Bool = true) async {
        persistence.clearPairedRelayConfiguration()
        pairedRelayConfiguration = nil
        lastErrorMessage = nil
        await sessionStore.clearSession()
        if notify {
            await onPairingChanged?(false)
        }
    }
}
