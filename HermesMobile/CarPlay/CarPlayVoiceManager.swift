import CarPlay
import UIKit

/// Bridges `TalkStore` voice state to the CarPlay `CPVoiceControlTemplate`.
/// Provides interactive controls: start session, mute, end, and interrupt.
/// Per iOS 26.4 Voice-Based Conversational category, `CPVoiceControlTemplate`
/// is the primary interface with action buttons below the voice visualization.
@MainActor
final class CarPlayVoiceManager {
    private static let maxTranscriptTitleLength = 80

    private let interfaceController: CPInterfaceController
    private var voiceTemplate: CPVoiceControlTemplate?
    private var observationTask: Task<Void, Never>?
    private var currentSpeakingTitle: String?
    private var lastSyncedStateID: String?
    private var lastActionSignature: String?

    private var talkStore: TalkStore { AppContainer.sharedDefault().talkStore }

    // MARK: - Voice Control State Identifiers

    private enum StateID {
        static let idle = "idle"
        static let listening = "listening"
        static let thinking = "thinking"
        static let speaking = "speaking"
        static let connecting = "connecting"
    }

    init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
    }

    // MARK: - Lifecycle

    func configure() {
        let initialSpeakingTitle = lastAssistantText()
        currentSpeakingTitle = initialSpeakingTitle
        setTemplate(
            speakingTitle: initialSpeakingTitle,
            activeStateID: currentStateIdentifier()
        )

        if talkStore.isSessionActive {
            syncState()
        }

        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self else { return }
                self.syncState()
            }
        }
    }

    func tearDown() {
        observationTask?.cancel()
        observationTask = nil
        voiceTemplate = nil
        lastSyncedStateID = nil
    }

    // MARK: - Template Construction

    private func setTemplate(speakingTitle: String?, activeStateID: String?) {
        let template = buildVoiceControlTemplate(speakingTitle: speakingTitle)
        voiceTemplate = template
        interfaceController.setRootTemplate(template, animated: false) { _, _ in
            guard let activeStateID else { return }
            template.activateVoiceControlState(withIdentifier: activeStateID)
        }
    }

    private func buildVoiceControlTemplate(speakingTitle: String?) -> CPVoiceControlTemplate {
        let idle = CPVoiceControlState(
            identifier: StateID.idle,
            titleVariants: ["Tap Start to talk to Hermes", "Talk to Hermes"],
            image: UIImage(systemName: "brain.head.profile")!,
            repeats: false
        )

        let connecting = CPVoiceControlState(
            identifier: StateID.connecting,
            titleVariants: ["Connecting to Hermes...", "Connecting..."],
            image: UIImage(systemName: "antenna.radiowaves.left.and.right")!,
            repeats: true
        )

        let listening = CPVoiceControlState(
            identifier: StateID.listening,
            titleVariants: ["Listening...", "Go ahead"],
            image: UIImage(systemName: "waveform")!,
            repeats: true
        )

        let thinking = CPVoiceControlState(
            identifier: StateID.thinking,
            titleVariants: ["Thinking...", "Working on it"],
            image: UIImage(systemName: "gear")!,
            repeats: true
        )

        let speaking = CPVoiceControlState(
            identifier: StateID.speaking,
            titleVariants: [speakingTitle ?? "Hermes is speaking", "Hermes is speaking"],
            image: UIImage(systemName: "speaker.wave.2.fill")!,
            repeats: false
        )

        let template = CPVoiceControlTemplate(
            voiceControlStates: [idle, connecting, listening, thinking, speaking]
        )

        if #available(iOS 26.4, *) {
            idle.actionButtons = buttons(for: StateID.idle)
            connecting.actionButtons = buttons(for: StateID.connecting)
            listening.actionButtons = buttons(for: StateID.listening)
            thinking.actionButtons = buttons(for: StateID.thinking)
            speaking.actionButtons = buttons(for: StateID.speaking)
        }

        return template
    }

    // MARK: - Action Buttons

    private func buttons(for stateID: String) -> [CPButton] {
        guard #available(iOS 26.4, *) else { return [] }

        switch stateID {
        case StateID.idle:
            return [startButton()]
        case StateID.connecting:
            return [endButton()]
        case StateID.speaking:
            return [interruptButton(), muteButton(), endButton()]
        case StateID.listening, StateID.thinking:
            return [muteButton(), endButton()]
        default:
            return []
        }
    }

    private func startButton() -> CPButton {
        let button = CPButton(
            image: UIImage(systemName: "play.fill")!,
            handler: { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.talkStore.startSessionDirectly()
                    self.syncState()
                }
            }
        )
        button.title = "Start"
        return button
    }

    private func muteButton() -> CPButton {
        let isMuted = talkStore.isMuted
        let button = CPButton(
            image: UIImage(systemName: isMuted ? "mic.slash.fill" : "mic.fill")!,
            handler: { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.talkStore.toggleMute()
                    self.syncState()
                }
            }
        )
        button.title = isMuted ? "Unmute" : "Mute"
        return button
    }

    private func endButton() -> CPButton {
        let button = CPButton(
            image: UIImage(systemName: "xmark.circle.fill")!,
            handler: { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.talkStore.endSession()
                    self.syncState()
                }
            }
        )
        button.title = "End"
        return button
    }

    private func interruptButton() -> CPButton {
        let button = CPButton(
            image: UIImage(systemName: "hand.raised.fill")!,
            handler: { [weak self] _ in
                guard let self else { return }
                self.talkStore.interruptAssistant()
                self.syncState()
            }
        )
        button.title = "Stop"
        return button
    }

    // MARK: - State Sync

    private func currentStateIdentifier() -> String {
        guard talkStore.isSessionActive else { return StateID.idle }

        switch talkStore.connectionState {
        case .connecting, .checking:
            return StateID.connecting
        default:
            break
        }

        switch talkStore.voiceState {
        case .listening:
            return StateID.listening
        case .thinking:
            return StateID.thinking
        case .speaking:
            return StateID.speaking
        case .interrupted:
            return StateID.listening
        case .idle, .disconnected:
            return StateID.idle
        }
    }

    private func actionSignature(for stateID: String) -> String {
        "\(stateID)|\(talkStore.isSessionActive)|\(talkStore.isMuted)"
    }

    private func syncState() {
        guard voiceTemplate != nil else { return }

        let stateID = currentStateIdentifier()
        let latestTitle = lastAssistantText()
        let actionSignature = actionSignature(for: stateID)

        if latestTitle != currentSpeakingTitle || actionSignature != lastActionSignature {
            currentSpeakingTitle = latestTitle
            lastActionSignature = actionSignature
            lastSyncedStateID = stateID
            setTemplate(speakingTitle: latestTitle, activeStateID: stateID)
            return
        }

        if stateID != lastSyncedStateID {
            lastSyncedStateID = stateID
            voiceTemplate?.activateVoiceControlState(withIdentifier: stateID)
        }
    }

    private func lastAssistantText() -> String {
        let lastAssistant = talkStore.transcriptItems.reversed().first(where: { $0.speaker == .hermes })
        let trimmed = lastAssistant?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return "Hermes is speaking" }
        return String(trimmed.prefix(Self.maxTranscriptTitleLength))
    }
}
