import Foundation

@MainActor
@Observable
final class SettingsStore {
    var settings: UserSettings {
        didSet {
            persistence.saveUserSettings(settings)
            if oldValue.environment != settings.environment {
                Task { await onEnvironmentChanged?(settings.environment) }
            }
        }
    }

    var onEnvironmentChanged: (@MainActor (AppEnvironment) async -> Void)?

    private let persistence: any AppPersistenceStoreProtocol

    init(persistence: any AppPersistenceStoreProtocol) {
        self.persistence = persistence
        self.settings = persistence.loadUserSettings() ?? DemoData.sampleUserSettings
    }
}
