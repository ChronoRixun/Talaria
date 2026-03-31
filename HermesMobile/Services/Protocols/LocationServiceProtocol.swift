import Foundation

@MainActor
protocol LocationServiceProtocol {
    var authorizationStatus: PermissionStatus { get }
    func requestAuthorization() async -> PermissionStatus
}
