import Foundation

@MainActor
protocol VoiceSessionServiceProtocol {
    var voiceState: VoiceState { get }
    var transcript: String { get }
    var sessionDuration: TimeInterval { get }
    var isMuted: Bool { get }
    func startSession() async
    func endSession() async
    func toggleMute() async
}
