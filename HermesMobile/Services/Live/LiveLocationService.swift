import CoreLocation

@MainActor
@Observable
final class LiveLocationService: NSObject, LocationServiceProtocol, CLLocationManagerDelegate {
    private(set) var authorizationStatus: PermissionStatus = .notDetermined

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<PermissionStatus, Never>?

    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = mapStatus(manager.authorizationStatus)
    }

    func requestAuthorization() async -> PermissionStatus {
        let current = manager.authorizationStatus
        guard current == .notDetermined else {
            authorizationStatus = mapStatus(current)
            return authorizationStatus
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            let mapped = mapStatus(status)
            authorizationStatus = mapped
            continuation?.resume(returning: mapped)
            continuation = nil
        }
    }

    private func mapStatus(_ status: CLAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .authorizedAlways, .authorizedWhenInUse: .authorized
        @unknown default: .notDetermined
        }
    }
}
