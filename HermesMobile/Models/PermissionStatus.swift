import SwiftUI

enum PermissionStatus: String, Codable, Hashable, Sendable {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted
    case unsupported

    var displayLabel: String {
        switch self {
        case .notDetermined: "Not Set"
        case .authorized: "Enabled"
        case .limited: "Limited"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .unsupported: "Unavailable"
        }
    }

    var displayColor: Color {
        switch self {
        case .notDetermined: .secondary
        case .authorized: .green
        case .limited: .orange
        case .denied: .red
        case .restricted: .orange
        case .unsupported: .secondary
        }
    }

    var actionLabel: String? {
        switch self {
        case .notDetermined: "Enable"
        case .authorized: nil
        case .limited: "Manage"
        case .denied: "Open Settings"
        case .restricted: nil
        case .unsupported: nil
        }
    }
}
