import Foundation

@MainActor
final class MockPairingService: PairingServiceProtocol {
    func decodeSetupCode(_ rawCode: String) throws -> RelaySetupCodePayload {
        try RelaySetupCodePayload.decode(from: rawCode)
    }

    func redeemSetupCode(
        payload: RelaySetupCodePayload,
        displayName: String,
        request: DeviceRegistrationRequest
    ) async throws -> PairingRedeemResult {
        PairingRedeemResult(
            configuration: PairedRelayConfiguration(
                baseURLString: payload.relayURL,
                hostDisplayName: payload.hostDisplayName,
                pairedAt: .now
            ),
            state: AppSessionState(
                userID: UUID(),
                displayName: displayName,
                deviceID: UUID(),
                installationID: request.installationID,
                deviceRegistered: true,
                connectionStatus: .connected,
                syncStatus: .synced,
                isMockMode: false,
                backendEndpoint: payload.relayURL,
                lastSyncAt: .now,
                pushTokenRegistered: false
            ),
            tokens: AuthTokens(
                accessToken: "mock-paired-access-token",
                refreshToken: "mock-paired-refresh-token",
                expiresAt: .distantFuture
            )
        )
    }
}
