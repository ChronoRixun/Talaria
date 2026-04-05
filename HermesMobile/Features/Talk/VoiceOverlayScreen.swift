import SwiftUI

/// Full-screen voice overlay, inspired by ChatGPT's voice mode.
/// Auto-starts a voice session on appear and tears it down on dismiss.
struct VoiceOverlayScreen: View {
    @Environment(TalkStore.self) private var talkStore
    @Environment(TabRouter.self) private var router

    var body: some View {
        ZStack {
            Design.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Text("Hermes")
                        .font(Design.Typography.headline)
                        .foregroundStyle(Design.Colors.foreground)
                    Text("Voice")
                        .font(Design.Typography.headline)
                        .foregroundStyle(Design.Colors.secondaryForeground)
                    Spacer()
                }
                .padding(.horizontal, Design.Spacing.lg)
                .padding(.top, Design.Spacing.md)

                Spacer()

                // Transcript area
                transcriptSection

                Spacer()

                // Voice orb
                VoiceOrb(voiceState: talkStore.voiceState)
                    .onTapGesture {
                        if talkStore.voiceState == .speaking {
                            talkStore.interruptAssistant()
                        }
                    }
                    .padding(.bottom, Design.Spacing.sm)

                // Status label — always visible, adapts to state
                orbStatusLabel
                    .padding(.horizontal, Design.Spacing.xl)
                    .animation(Design.Motion.quickResponse, value: talkStore.connectionState)
                    .animation(Design.Motion.quickResponse, value: talkStore.voiceState)

                Spacer()

                // Bottom controls
                controlBar
                    .padding(.bottom, Design.Spacing.xxl)
            }
        }
        .task {
            await talkStore.refreshReadiness()
            if talkStore.canStartSession {
                await talkStore.startSession()
            }
        }
        .statusBarHidden(true)
    }

    // MARK: - Transcript

    private var transcriptSection: some View {
        ScrollView {
            LazyVStack(spacing: Design.Spacing.sm) {
                ForEach(talkStore.transcriptItems) { item in
                    transcriptBubble(item)
                }
            }
            .padding(.horizontal, Design.Spacing.lg)
        }
        .scrollDismissesKeyboard(.never)
        .defaultScrollAnchor(.bottom)
        .frame(maxHeight: 200)
    }

    @ViewBuilder
    private func transcriptBubble(_ item: TranscriptItem) -> some View {
        switch item.speaker {
        case .user:
            HStack {
                Spacer()
                Text(item.text)
                    .font(Design.Typography.body)
                    .foregroundStyle(Design.Colors.foreground)
                    .padding(.horizontal, Design.Spacing.md)
                    .padding(.vertical, Design.Spacing.sm)
                    .background(Design.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Design.CornerRadius.xl))
                    .opacity(item.isPartial ? 0.6 : 1)
            }
        case .hermes:
            HStack {
                Text(item.text)
                    .font(Design.Typography.body)
                    .foregroundStyle(Design.Colors.foreground)
                    .opacity(item.isPartial ? 0.6 : 1)
                Spacer()
            }
        case .system:
            Text(item.text)
                .font(Design.Typography.caption)
                .foregroundStyle(Design.Colors.secondaryForeground)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Orb Status

    @ViewBuilder
    private var orbStatusLabel: some View {
        switch (talkStore.connectionState, talkStore.voiceState) {
        case (.failed, _), (.blocked, _):
            // Error states
            VStack(spacing: Design.Spacing.xs) {
                if let blocked = talkStore.blockedReason {
                    Text(blocked)
                        .font(Design.Typography.callout)
                        .foregroundStyle(Design.Colors.secondaryForeground)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Unable to connect")
                        .font(Design.Typography.callout)
                        .foregroundStyle(Design.Colors.secondaryForeground)
                }
            }

        case (.checking, _), (.idle, _):
            HStack(spacing: Design.Spacing.xs) {
                ProgressView()
                    .controlSize(.small)
                    .tint(Design.Colors.secondaryForeground)
                Text("Checking\u{2026}")
                    .font(Design.Typography.callout)
                    .foregroundStyle(Design.Colors.secondaryForeground)
            }

        case (.connecting, _):
            HStack(spacing: Design.Spacing.xs) {
                ProgressView()
                    .controlSize(.small)
                    .tint(Design.Colors.secondaryForeground)
                Text("Connecting\u{2026}")
                    .font(Design.Typography.callout)
                    .foregroundStyle(Design.Colors.secondaryForeground)
            }

        case (.connected, .listening):
            Text("Listening")
                .font(Design.Typography.callout)
                .foregroundStyle(Design.Colors.secondaryForeground)

        case (.connected, .thinking):
            Text(talkStore.statusMessage ?? "Thinking\u{2026}")
                .font(Design.Typography.callout)
                .foregroundStyle(Design.Colors.secondaryForeground)

        case (.connected, .speaking):
            Text("Tap orb to interrupt")
                .font(Design.Typography.caption)
                .foregroundStyle(Design.Colors.secondaryForeground.opacity(0.7))

        case (_, .disconnected):
            Text("Disconnected")
                .font(Design.Typography.callout)
                .foregroundStyle(Design.Colors.secondaryForeground)

        default:
            EmptyView()
        }
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: Design.Spacing.xl) {
            if talkStore.isSessionActive {
                // Mute button
                Button {
                    Task { await talkStore.toggleMute() }
                } label: {
                    Image(systemName: talkStore.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(talkStore.isMuted ? .red : Design.Colors.foreground)
                        .frame(width: 52, height: 52)
                        .background(Design.Colors.surface)
                        .clipShape(Circle())
                }
                .accessibilityLabel(talkStore.isMuted ? "Unmute" : "Mute")

                Spacer()

                // Session timer
                if talkStore.isSessionActive {
                    Text(formattedDuration)
                        .font(Design.Typography.caption.monospacedDigit())
                        .foregroundStyle(Design.Colors.secondaryForeground)
                }

                Spacer()

                // Close button
                Button {
                    Task {
                        await talkStore.endSession()
                        router.isVoiceOverlayPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Design.Colors.foreground)
                        .frame(width: 52, height: 52)
                        .background(Design.Colors.surface)
                        .clipShape(Circle())
                }
                .accessibilityLabel("End voice session")
            } else {
                Spacer()

                // Close button when not active (e.g. failed to start)
                Button {
                    router.isVoiceOverlayPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Design.Colors.foreground)
                        .frame(width: 52, height: 52)
                        .background(Design.Colors.surface)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Close")
            }
        }
        .padding(.horizontal, Design.Spacing.xl)
    }

    private var formattedDuration: String {
        let minutes = Int(talkStore.sessionDuration) / 60
        let seconds = Int(talkStore.sessionDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
