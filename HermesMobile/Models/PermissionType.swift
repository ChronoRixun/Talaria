import SwiftUI

enum PermissionType: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case location
    case health
    case notifications
    case microphone
    case camera
    case photos

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .location: "Location"
        case .health: "Health"
        case .notifications: "Notifications"
        case .microphone: "Microphone"
        case .camera: "Camera"
        case .photos: "Photos"
        }
    }

    var displayIcon: String {
        switch self {
        case .location: "location.fill"
        case .health: "heart.fill"
        case .notifications: "bell.fill"
        case .microphone: "mic.fill"
        case .camera: "camera.fill"
        case .photos: "photo.fill"
        }
    }

    var displayColor: Color {
        switch self {
        case .location: .blue
        case .health: .red
        case .notifications: .orange
        case .microphone: .indigo
        case .camera: .purple
        case .photos: .green
        }
    }

    var explanation: String {
        switch self {
        case .location:
            "Hermes uses your location to provide contextual recommendations, weather updates, and nearby suggestions."
        case .health:
            "Access your health data to offer personalized wellness insights, activity tracking, and sleep recommendations."
        case .notifications:
            "Receive timely reminders, task updates, and important alerts from Hermes."
        case .microphone:
            "Voice conversations with Hermes in Talk Mode."
        case .camera:
            "Capture photos and documents for Hermes to analyze, annotate, or organize."
        case .photos:
            "Access your photo library to help organize, search, and create albums based on your preferences."
        }
    }

    /// Permissions shown during onboarding. Camera and Photos are deferred to Settings.
    static let onboardingPermissions: [PermissionType] = [.location, .notifications, .health, .microphone]
}
