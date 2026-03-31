import Foundation

@MainActor
@Observable
final class TalkStore {
    var voiceState: VoiceState = .idle
    var transcript: String = ""
    var sessionDuration: TimeInterval = 0
    var isMuted = false
    var isSessionActive = false

    private let voiceService: any VoiceSessionServiceProtocol
    private var pollingTask: Task<Void, Never>?

    init(voiceService: any VoiceSessionServiceProtocol) {
        self.voiceService = voiceService
        syncFromService()
    }

    func startSession() async {
        isSessionActive = true
        await voiceService.startSession()
        startPolling()
    }

    func endSession() async {
        await voiceService.endSession()
        isSessionActive = false
        stopPolling()
        syncFromService()
    }

    func toggleMute() async {
        await voiceService.toggleMute()
        syncFromService()
    }

    private func startPolling() {
        stopPolling()
        pollingTask = Task {
            while !Task.isCancelled {
                syncFromService()
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func syncFromService() {
        voiceState = voiceService.voiceState
        transcript = voiceService.transcript
        sessionDuration = voiceService.sessionDuration
        isMuted = voiceService.isMuted
    }
}
