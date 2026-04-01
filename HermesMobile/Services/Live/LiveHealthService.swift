import HealthKit

@MainActor
@Observable
final class LiveHealthService: HealthServiceProtocol {
    private(set) var authorizationStatus: PermissionStatus

    private let store: HKHealthStore?
    private let readTypes: Set<HKObjectType>

    init() {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.store = nil
            self.readTypes = []
            self.authorizationStatus = .unsupported
            return
        }

        let store = HKHealthStore()
        self.store = store
        var types = Set<HKObjectType>()
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        self.readTypes = types

        // HealthKit doesn't expose read-only authorization status for privacy.
        // Default to notDetermined until the user explicitly requests access.
        self.authorizationStatus = .notDetermined
    }

    func requestAuthorization() async -> PermissionStatus {
        guard let store else {
            authorizationStatus = .unsupported
            return .unsupported
        }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            // After requesting, HealthKit always returns .notDetermined for read-only.
            // Treat a successful request as "limited" (user saw the dialog).
            authorizationStatus = .limited
        } catch {
            authorizationStatus = .denied
        }

        return authorizationStatus
    }
}
