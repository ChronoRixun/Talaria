import Foundation

@MainActor
final class LiveHermesHostService: HermesHostServiceProtocol {
    private struct EmptyBody: Encodable {}

    private struct EnrollmentResponse: Decodable {
        let setupCode: String
        let expiresAt: Date?
        let relayHost: String
    }

    private struct CurrentHostResponse: Decodable {
        let host: RelayHost?
    }

    private struct RelayHost: Decodable {
        let id: UUID
        let displayName: String?
        let hostname: String?
        let platform: String?
        let connectorVersion: String?
        let hermesCommand: String?
        let hermesVersion: String?
        let lastSeenAt: Date?
        let lastConnectedAt: Date?
        let isOnline: Bool
    }

    private let apiClient: RelayAPIClient

    init(apiClient: RelayAPIClient) {
        self.apiClient = apiClient
    }

    func fetchCurrentHost(accessToken: String?) async throws -> HermesHostStatus? {
        let response: CurrentHostResponse = try await apiClient.get(
            path: "hosts/current",
            accessToken: accessToken
        )
        guard let host = response.host else { return nil }
        return mapHost(host)
    }

    func createEnrollmentCode(accessToken: String?) async throws -> HostEnrollmentCode {
        let response: EnrollmentResponse = try await apiClient.post(
            path: "hosts/enrollment-codes",
            body: EmptyBody(),
            accessToken: accessToken
        )
        return HostEnrollmentCode(
            setupCode: response.setupCode,
            expiresAt: response.expiresAt,
            relayHost: response.relayHost
        )
    }

    func revokeCurrentHost(accessToken: String?) async throws {
        let _: EmptyResponse = try await apiClient.post(
            path: "hosts/current/revoke",
            body: EmptyBody(),
            accessToken: accessToken
        )
    }

    private func mapHost(_ host: RelayHost) -> HermesHostStatus {
        HermesHostStatus(
            id: host.id,
            displayName: host.displayName,
            hostname: host.hostname,
            platform: host.platform,
            connectorVersion: host.connectorVersion,
            hermesCommand: host.hermesCommand,
            hermesVersion: host.hermesVersion,
            lastSeenAt: host.lastSeenAt,
            lastConnectedAt: host.lastConnectedAt,
            isOnline: host.isOnline
        )
    }
}

private struct EmptyResponse: Decodable {}
