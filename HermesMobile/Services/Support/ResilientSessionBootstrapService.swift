import Foundation

@MainActor
final class ResilientSessionBootstrapService: SessionBootstrapServiceProtocol {
    private let primary: any SessionBootstrapServiceProtocol
    private let fallback: any SessionBootstrapServiceProtocol

    init(
        primary: any SessionBootstrapServiceProtocol,
        fallback: any SessionBootstrapServiceProtocol
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    func registerDevice(_ request: DeviceRegistrationRequest) async throws -> SessionBootstrapResponse {
        do {
            return try await primary.registerDevice(request)
        } catch {
            return try await fallback.registerDevice(request)
        }
    }

    func loadSession(accessToken: String?) async throws -> AppSessionState {
        do {
            return try await primary.loadSession(accessToken: accessToken)
        } catch {
            return try await fallback.loadSession(accessToken: accessToken)
        }
    }

    func refreshAuth(refreshToken: String) async throws -> AuthTokens {
        do {
            return try await primary.refreshAuth(refreshToken: refreshToken)
        } catch {
            return try await fallback.refreshAuth(refreshToken: refreshToken)
        }
    }
}
