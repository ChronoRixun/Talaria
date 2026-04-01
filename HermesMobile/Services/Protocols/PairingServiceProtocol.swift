import Foundation

@MainActor
protocol PairingServiceProtocol {
    func decodeSetupCode(_ rawCode: String) throws -> RelaySetupCodePayload
    func redeemSetupCode(
        payload: RelaySetupCodePayload,
        displayName: String,
        request: DeviceRegistrationRequest
    ) async throws -> PairingRedeemResult
}
