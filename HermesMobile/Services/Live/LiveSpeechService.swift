@preconcurrency import AVFoundation
import Foundation
@preconcurrency import Speech

/// On-device speech-to-text using Apple's Speech framework.
/// Used for dictation in the chat composer — not for voice mode (which uses OpenAI Realtime).
///
/// This uses the modern iOS 26 Speech analyzer/transcriber stack instead of the
/// older `SFSpeechRecognizer` live-audio callback path. The newer APIs are a much
/// better fit for Swift concurrency and are less fragile around queue ownership.
@MainActor
@Observable
final class LiveSpeechService {
    private(set) var isListening = false
    private(set) var transcript = ""
    private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    var onAutoStop: ((_ finalTranscript: String) -> Void)?
    var onTranscriptChange: ((_ transcript: String) -> Void)?

    private let controller = DictationController()
    private var streamTask: Task<Void, Never>?

    var supportsOnDevice: Bool {
        true
    }

    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume(returning: status)
                }
            }
        }
    }

    func startListening() async throws {
        let speechAuthorized: Bool
        if authorizationStatus == .authorized {
            speechAuthorized = true
        } else {
            speechAuthorized = await requestAuthorization() == .authorized
        }
        guard speechAuthorized else {
            throw SpeechError.unavailable
        }

        let microphoneStatus = AVAudioApplication.shared.recordPermission
        if microphoneStatus == .undetermined {
            guard await AVAudioApplication.requestRecordPermission() else {
                throw SpeechError.microphoneDenied
            }
        } else if microphoneStatus != .granted {
            throw SpeechError.microphoneDenied
        }

        guard !isListening else { return }

        transcript = ""
        streamTask?.cancel()

        let stream = try await controller.start()
        isListening = true

        streamTask = Task { [weak self] in
            guard let self else { return }
            for await event in stream {
                await MainActor.run {
                    switch event {
                    case .partial(let text):
                        self.transcript = text
                        self.onTranscriptChange?(text)
                    case .finished(let text):
                        self.transcript = text
                        self.isListening = false
                        self.onTranscriptChange?(text)
                        if !text.isEmpty {
                            self.onAutoStop?(text)
                        }
                    case .failed:
                        self.isListening = false
                    }
                }
            }
        }
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false
        streamTask?.cancel()
        streamTask = nil

        Task {
            await controller.stop()
        }
    }

    enum SpeechError: LocalizedError {
        case unavailable
        case microphoneDenied

        var errorDescription: String? {
            switch self {
            case .unavailable:
                "Speech recognition is not available on this device."
            case .microphoneDenied:
                "Microphone access is required for dictation."
            }
        }
    }
}

private actor DictationController {
    enum Event: Sendable {
        case partial(String)
        case finished(String)
        case failed
    }

    private let transcriber = DictationTranscriber(locale: .current, preset: .progressiveShortDictation)
    private let audioEngine = AVAudioEngine()

    private var analyzer: SpeechAnalyzer?
    private var analyzerTask: Task<Void, Never>?
    private var resultsTask: Task<Void, Never>?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var outputContinuation: AsyncStream<Event>.Continuation?

    func start() async throws -> AsyncStream<Event> {
        await stop()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let format = inputNode.outputFormat(forBus: 0)

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.prepareToAnalyze(in: format)
        self.analyzer = analyzer

        var localInputContinuation: AsyncStream<AnalyzerInput>.Continuation?
        let inputStream = AsyncStream<AnalyzerInput> { continuation in
            localInputContinuation = continuation
            self.inputContinuation = continuation
        }

        let outputStream = AsyncStream<Event> { continuation in
            self.outputContinuation = continuation
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            localInputContinuation?.yield(AnalyzerInput(buffer: buffer))
        }

        audioEngine.prepare()
        try audioEngine.start()

        analyzerTask = Task { [weak self] in
            do {
                try await analyzer.start(inputSequence: inputStream)
            } catch {
                await self?.emit(.failed)
                await self?.stop()
            }
        }

        let transcriber = self.transcriber
        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    if result.isFinal {
                        await self?.emit(.finished(text))
                        await self?.stop()
                        break
                    } else {
                        await self?.emit(.partial(text))
                    }
                }
            } catch {
                await self?.emit(.failed)
                await self?.stop()
            }
        }

        return outputStream
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        inputContinuation?.finish()
        inputContinuation = nil

        analyzerTask?.cancel()
        resultsTask?.cancel()
        analyzerTask = nil
        resultsTask = nil

        let analyzer = analyzer
        self.analyzer = nil
        if let analyzer {
            Task {
                await analyzer.cancelAndFinishNow()
            }
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        outputContinuation?.finish()
        outputContinuation = nil
    }

    private func emit(_ event: Event) {
        outputContinuation?.yield(event)
    }
}
