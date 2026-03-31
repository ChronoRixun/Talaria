import Foundation

struct UserSettings: Codable, Hashable, Sendable {
    var userName: String
    var avatarInitials: String
    var notificationsEnabled: Bool
    var hapticFeedbackEnabled: Bool
    var analyticsEnabled: Bool
    var environment: AppEnvironment
    var autoConnectOnLaunch: Bool

    init(
        userName: String = "User",
        avatarInitials: String = "U",
        notificationsEnabled: Bool = true,
        hapticFeedbackEnabled: Bool = true,
        analyticsEnabled: Bool = false,
        environment: AppEnvironment = .production,
        autoConnectOnLaunch: Bool = true
    ) {
        self.userName = userName
        self.avatarInitials = avatarInitials
        self.notificationsEnabled = notificationsEnabled
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
        self.analyticsEnabled = analyticsEnabled
        self.environment = environment
        self.autoConnectOnLaunch = autoConnectOnLaunch
    }
}

enum AppEnvironment: String, Codable, CaseIterable, Hashable, Sendable {
    case production
    case staging
    case development

    var displayLabel: String {
        switch self {
        case .production: "Production"
        case .staging: "Staging"
        case .development: "Development"
        }
    }

    var baseURLString: String {
        switch self {
        case .production: "https://relay.example.com/v1"
        case .staging: "https://staging.relay.example.com/v1"
        case .development: "http://127.0.0.1:8000/v1"
        }
    }
}
