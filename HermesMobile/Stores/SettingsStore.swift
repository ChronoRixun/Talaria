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
    var availableEnvironments: [AppEnvironment] {
        environmentPolicy.availableEnvironments
    }

    private let persistence: any AppPersistenceStoreProtocol
    private let environmentPolicy: AppEnvironmentPolicy

    init(
        persistence: any AppPersistenceStoreProtocol,
        environmentPolicy: AppEnvironmentPolicy = .currentBuild
    ) {
        self.persistence = persistence
        self.environmentPolicy = environmentPolicy
        let storedSettings = persistence.loadUserSettings() ?? DemoData.sampleUserSettings
        self.settings = storedSettings.applyingEnvironmentPolicy(environmentPolicy)
    }
}
