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

            // Use the native timer when a start date is available —
            // this ticks in real-time without needing Live Activity updates.
            if let start = context.state.startDate {
                Text(timerInterval: start...Date.distantFuture, countsDown: false)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            } else if context.state.elapsedSeconds > 0 {
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

// Previews are in HermesMobile/Features/Talk/LiveActivityPreviews.swift
// (Widget extension targets cannot host previews.)
