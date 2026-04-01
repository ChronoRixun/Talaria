import Foundation

@MainActor
@Observable
final class HermesHostStore {
    var currentHost: HermesHostStatus?
    var activeEnrollmentCode: HostEnrollmentCode?
    var isLoading = false
    var isWorking = false
    var lastErrorMessage: String?

    private let hostService: any HermesHostServiceProtocol
    private let accessTokenProvider: @MainActor () async -> String?

    init(
        hostService: any HermesHostServiceProtocol,
        accessTokenProvider: @escaping @MainActor () async -> String?
    ) {
        self.hostService = hostService
        self.accessTokenProvider = accessTokenProvider
    }

    var isHostOnline: Bool {
        currentHost?.isOnline == true
    }

    func refresh() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            currentHost = try await hostService.fetchCurrentHost(accessToken: await accessTokenProvider())
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func generateEnrollmentCode() async {
        guard !isWorking else { return }

        isWorking = true
        defer { isWorking = false }

        do {
            activeEnrollmentCode = try await hostService.createEnrollmentCode(accessToken: await accessTokenProvider())
            currentHost = try await hostService.fetchCurrentHost(accessToken: await accessTokenProvider())
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func revokeCurrentHost() async {
        guard !isWorking else { return }

        isWorking = true
        defer { isWorking = false }

        do {
            try await hostService.revokeCurrentHost(accessToken: await accessTokenProvider())
            currentHost = nil
            activeEnrollmentCode = nil
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func reset() {
        currentHost = nil
        activeEnrollmentCode = nil
        isLoading = false
        isWorking = false
        lastErrorMessage = nil
    }
}
