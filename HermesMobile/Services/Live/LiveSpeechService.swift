import AVFoundation
import Foundation
import Speech

/// On-device speech-to-text using Apple's Speech framework.
/// Used for dictation in the chat composer — not for voice mode (which uses OpenAI Realtime).
@MainActor
@Observable
final class LiveSpeechService {
    private(set) var isListening = false
    private(set) var transcript = ""
    private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    /// Called when the recognizer auto-stops (final result or error).
    /// The caller should commit the transcript to its text field.
    var onAutoStop: ((_ finalTranscript: String) -> Void)?
    /// Called whenever a partial or final transcript update arrives.
    var onTranscriptChange: ((_ transcript: String) -> Void)?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var activeSessionID = UUID()

    var supportsOnDevice: Bool {
        speechRecognizer?.supportsOnDeviceRecognition ?? false
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
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.unavailable
        }
        guard !isListening else { return }

        let microphoneStatus = AVAudioApplication.shared.recordPermission
        if microphoneStatus == .undetermined {
            guard await AVAudioApplication.requestRecordPermission() else {
                throw SpeechError.microphoneDenied
            }
        } else if microphoneStatus == .denied {
            throw SpeechError.microphoneDenied
        } else if microphoneStatus != .granted {
            throw SpeechError.microphoneDenied
        }

        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        activeSessionID = UUID()

        // Use Apple's live-audio speech-recognition audio-session guidance.
        // Dictation is record-only; using `.measurement` is less likely to
        // fight the app's WebRTC playback/record paths than `.playAndRecord`.
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        transcript = ""
        let sessionID = activeSessionID

        do {
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            recognitionRequest = request
            isListening = true

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                let latestTranscript = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal == true
                let shouldFinish = error != nil || isFinal

                if shouldFinish {
                    inputNode.removeTap(onBus: 0)
                    self?.audioEngine.stop()
                    request.endAudio()
                    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                }

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard self.activeSessionID == sessionID else { return }

                    if let latestTranscript {
                        self.transcript = latestTranscript
                        self.onTranscriptChange?(self.transcript)
                    }

                    if shouldFinish {
                        let finalTranscript = self.transcript
                        self.recognitionRequest = nil
                        self.recognitionTask = nil
                        self.isListening = false
                        // Notify the caller so it can commit the transcript
                        if !finalTranscript.isEmpty {
                            self.onAutoStop?(finalTranscript)
                        }
                    }
                }
            }
        } catch {
            inputNode.removeTap(onBus: 0)
            audioEngine.stop()
            request.endAudio()
            recognitionRequest = nil
            recognitionTask?.cancel()
            recognitionTask = nil
            isListening = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }
    }

    func stopListening() {
        guard isListening else { return }
        activeSessionID = UUID()

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        isListening = false
        recognitionTask = nil

        // Deactivate the audio session so it doesn't conflict with WebRTC
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
