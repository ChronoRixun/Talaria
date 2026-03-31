import SwiftUI

enum VoiceState: String, Codable, Hashable, Sendable, CaseIterable {
    case idle
    case listening
    case thinking
    case speaking
    case disconnected

    var displayLabel: String {
        switch self {
        case .idle: "Ready"
        case .listening: "Listening"
        case .thinking: "Thinking"
        case .speaking: "Speaking"
        case .disconnected: "Disconnected"
        }
    }

    var displayIcon: String {
        switch self {
        case .idle: "mic.slash"
        case .listening: "mic.fill"
        case .thinking: "brain"
        case .speaking: "speaker.wave.2.fill"
        case .disconnected: "wifi.slash"
        }
    }

    var displayColor: Color {
        switch self {
        case .idle: .secondary
        case .listening: .blue
        case .thinking: .purple
        case .speaking: .green
        case .disconnected: .red
        }
    }
}
