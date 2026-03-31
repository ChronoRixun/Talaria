import Foundation

@MainActor
@Observable
final class MockLocationService: LocationServiceProtocol {
    var authorizationStatus: PermissionStatus = .notDetermined

    func requestAuthorization() async -> PermissionStatus {
        try? await Task.sleep(for: .seconds(0.5))
        authorizationStatus = .authorized
        return .authorized
    }
}
