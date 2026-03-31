import SwiftUI

struct TranscriptView: View {
    let transcript: String
    let voiceState: VoiceState

    var body: some View {
        VStack(spacing: Design.Spacing.xs) {
            if !transcript.isEmpty {
                Text(transcript)
                    .font(Design.Typography.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Design.Spacing.lg)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            Text(voiceState.displayLabel)
                .font(Design.Typography.caption)
                .foregroundStyle(voiceState.displayColor)
                .animation(Design.Motion.quickResponse, value: voiceState)
        }
        .padding(.horizontal, Design.Spacing.md)
    }
}
