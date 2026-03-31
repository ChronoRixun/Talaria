import SwiftUI

struct VoiceOrb: View {
    let voiceState: VoiceState

    @State private var pulseScale: CGFloat = 1.0
    @State private var innerRotation: Double = 0

    private var orbColor: Color { voiceState.displayColor }

    var body: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .fill(orbColor.opacity(0.15))
                .frame(width: Design.Size.voiceOrbSize * 1.3, height: Design.Size.voiceOrbSize * 1.3)
                .scaleEffect(pulseScale)

            // Middle ring
            Circle()
                .fill(orbColor.opacity(0.1))
                .frame(width: Design.Size.voiceOrbSize * 1.15, height: Design.Size.voiceOrbSize * 1.15)
                .scaleEffect(pulseScale * 0.95)

            // Main orb
            Circle()
                .fill(orbColor.gradient)
                .frame(width: Design.Size.voiceOrbSize, height: Design.Size.voiceOrbSize)
                .glassEffect(.regular, in: Circle())
                .overlay {
                    Image(systemName: voiceState.displayIcon)
                        .font(.system(size: Design.Size.iconHero, weight: .light))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(isThinking ? innerRotation : 0))
                }
        }
        .onChange(of: voiceState) {
            updateAnimation()
        }
        .onAppear { updateAnimation() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Voice status: \(voiceState.displayLabel)")
    }

    private var isThinking: Bool { voiceState == .thinking }

    private func updateAnimation() {
        switch voiceState {
        case .idle, .disconnected:
            withAnimation(Design.Motion.gentle) { pulseScale = 1.0 }
            innerRotation = 0
        case .listening:
            withAnimation(Design.Motion.breathe) { pulseScale = 1.08 }
        case .thinking:
            withAnimation(Design.Motion.pulse) { pulseScale = 1.04 }
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                innerRotation = 360
            }
        case .speaking:
            withAnimation(Design.Motion.breathe) { pulseScale = 1.12 }
            innerRotation = 0
        }
    }
}
