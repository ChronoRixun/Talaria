import ActivityKit
import SwiftUI
import WidgetKit

struct HermesLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HermesActivityAttributes.self) { context in
            // Lock Screen layout
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view (long press on Dynamic Island)
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.agentName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(context.state.status)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let tool = context.state.toolName {
                        Text(tool)
                            .font(.caption2)
                            .foregroundStyle(.yellow.opacity(0.7))
                    }
                }
            } compactLeading: {
                // Compact left side of Dynamic Island
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            } compactTrailing: {
                // Compact right side
                Text(context.state.status.prefix(12))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            } minimal: {
                // Minimal (when multiple Live Activities compete)
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.yellow)
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<HermesActivityAttributes>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 44, height: 44)
                .background(Color.yellow.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.agentName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(context.state.status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let tool = context.state.toolName {
                    Text(tool)
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }

            Spacer()

            if context.state.elapsedSeconds > 0 {
                Text(formatDuration(context.state.elapsedSeconds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Previews

#Preview("Lock Screen — Listening", as: .content, using: HermesActivityAttributes()) {
    HermesLiveActivity()
} contentStates: {
    HermesActivityAttributes.ContentState(status: "Listening", toolName: nil, elapsedSeconds: 12, sessionType: "voice")
}

#Preview("Lock Screen — Tool Call", as: .content, using: HermesActivityAttributes()) {
    HermesLiveActivity()
} contentStates: {
    HermesActivityAttributes.ContentState(status: "Working on that...", toolName: "hermes_delegate", elapsedSeconds: 45, sessionType: "voice")
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: HermesActivityAttributes()) {
    HermesLiveActivity()
} contentStates: {
    HermesActivityAttributes.ContentState(status: "Listening", toolName: nil, elapsedSeconds: 8, sessionType: "voice")
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: HermesActivityAttributes()) {
    HermesLiveActivity()
} contentStates: {
    HermesActivityAttributes.ContentState(status: "Working on that...", toolName: "hermes_delegate", elapsedSeconds: 32, sessionType: "voice")
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: HermesActivityAttributes()) {
    HermesLiveActivity()
} contentStates: {
    HermesActivityAttributes.ContentState(status: "Thinking", toolName: nil, elapsedSeconds: 5, sessionType: "voice")
}
