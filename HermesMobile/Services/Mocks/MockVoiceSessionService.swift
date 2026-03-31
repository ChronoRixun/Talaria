import Foundation

@MainActor
@Observable
final class MockVoiceSessionService: VoiceSessionServiceProtocol {
    var voiceState: VoiceState = .idle
    var transcript: String = ""
    var sessionDuration: TimeInterval = 0
    var isMuted: Bool = false

    private var sessionTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    func startSession() async {
        voiceState = .listening
        sessionDuration = 0
        transcript = ""

        // Start session timer
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled {
                    sessionDuration += 1
                }
            }
        }

        // Simulate voice state cycle
        sessionTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            voiceState = .thinking
            transcript = "Tell me about the weather forecast for this weekend..."

            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            voiceState = .speaking

            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            voiceState = .listening
        }
    }

    func endSession() async {
        sessionTask?.cancel()
        timerTask?.cancel()
        sessionTask = nil
        timerTask = nil
        voiceState = .idle
    }

    func toggleMute() async {
        isMuted.toggle()
    }
}
