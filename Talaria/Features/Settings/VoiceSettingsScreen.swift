import SwiftUI

// MARK: - Voice settings screen (Settings → EXPERIENCE → Voice)
//
// Truthful, read-only status + launch surface for the realtime Talk engine
// (LiveVoiceSessionService — WebRTC speech-to-speech). The iOS surface does NOT
// set model or voice; those are server-driven and shown read-only. Every field
// binds to a real TalkStore value; "—" is rendered wherever a value isn't yet
// knowable (e.g. latency before the first session of this launch).
struct VoiceSettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TalkStore.self) private var talkStore
    @Environment(TabRouter.self) private var router

    @State private var isRefreshing = false

    var body: some View {
        ZStack {
            HUDScreenBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Design.Spacing.lg) {
                    SettingsScreenHeader(title: "Voice", subtitle: "Talk engine · Realtime") { dismiss() }
                    statusSection
                    sessionSection
                    latencySection
                    launchSection
                }
                .padding(.horizontal, Design.Spacing.md)
                .padding(.vertical, Design.Spacing.sm)
            }
        }
        .navigationTitle("Voice")
        .toolbarVisibility(.hidden, for: .navigationBar)
        .task { await refresh() }
    }

    // MARK: Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sm) {
            HStack {
                MonoLabel("// Status", size: 10, tracking: Design.Tracking.monoXWide,
                          color: Design.Colors.mutedForeground)
                Spacer()
                Button { Task { await refresh() } } label: {
                    MonoLabel(isRefreshing ? "CHECKING…" : "RE-CHECK ›", size: 9, weight: .medium,
                              tracking: Design.Tracking.mono, color: Design.Colors.accentTint(0.7))
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
            }

            VStack(spacing: 0) {
                statusRow("Host", value: talkStore.hostOnline ? "ONLINE" : "OFFLINE",
                          color: talkStore.hostOnline ? Design.Brand.accent : Design.Colors.danger)
                rowDivider
                statusRow("Configured", value: talkStore.configured ? "YES" : "NO",
                          color: talkStore.configured ? Design.Brand.accent : Design.Brand.forge)
                rowDivider
                statusRow("Talk", value: talkStore.canStartSession ? "READY" : "BLOCKED",
                          color: talkStore.canStartSession ? Design.Brand.accent : Design.Colors.danger)
            }
            .hudPanel(cornerRadius: Design.CornerRadius.lg,
                      borderColor: Design.Colors.accentTint(0.12),
                      fill: Design.Colors.background.opacity(0.5), innerGlow: false)

            if let reason = talkStore.blockedReason, !reason.isEmpty, !talkStore.canStartSession {
                Text(reason)
                    .font(Design.Typography.caption)
                    .foregroundStyle(Design.Colors.secondaryForeground)
                    .padding(.horizontal, Design.Spacing.xxs)
            }
        }
    }

    // MARK: Session (server-driven, read-only)

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sm) {
            MonoLabel("// Session", size: 10, tracking: Design.Tracking.monoXWide,
                      color: Design.Colors.mutedForeground)

            VStack(spacing: 0) {
                statusRow("Model", value: talkStore.selectedModel ?? "—", color: tone(talkStore.selectedModel != nil))
                rowDivider
                statusRow("Voice", value: talkStore.serverVoice ?? "—", color: tone(talkStore.serverVoice != nil))
                rowDivider
                statusRow("Context updated", value: fmtDate(talkStore.voiceContextUpdatedAt),
                          color: tone(talkStore.voiceContextUpdatedAt != nil))
            }
            .hudPanel(cornerRadius: Design.CornerRadius.lg,
                      borderColor: Design.Colors.accentTint(0.12),
                      fill: Design.Colors.background.opacity(0.5), innerGlow: false)

            Text("Model and voice are selected on the host. The app shows them read-only.")
                .font(Design.Typography.caption)
                .foregroundStyle(Design.Colors.secondaryForeground)
                .padding(.horizontal, Design.Spacing.xxs)
        }
    }

    // MARK: Latency (last session this launch)

    private var latencySection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sm) {
            MonoLabel("// Last-session latency", size: 10, tracking: Design.Tracking.monoXWide,
                      color: Design.Colors.mutedForeground)

            VStack(spacing: 0) {
                statusRow("Relay bootstrap", value: fmtMs(talkStore.latencyMetrics.bootstrapLatency),
                          color: tone(talkStore.latencyMetrics.bootstrapLatency != nil))
                rowDivider
                statusRow("Realtime connect", value: fmtMs(talkStore.latencyMetrics.connectLatency),
                          color: tone(talkStore.latencyMetrics.connectLatency != nil))
                rowDivider
                statusRow("First reply", value: fmtMs(talkStore.latencyMetrics.firstAssistantLatency),
                          color: tone(talkStore.latencyMetrics.firstAssistantLatency != nil))
            }
            .hudPanel(cornerRadius: Design.CornerRadius.lg,
                      borderColor: Design.Colors.accentTint(0.12),
                      fill: Design.Colors.background.opacity(0.5), innerGlow: false)
        }
    }

    // MARK: Launch

    private var launchSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.xs) {
            Button {
                router.isVoiceOverlayPresented = true
            } label: {
                HStack(spacing: Design.Spacing.sm) {
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Start Voice Session")
                        .font(Design.Typography.display(13, weight: .semibold, relativeTo: .body))
                        .tracking(Design.Tracking.button)
                    Spacer()
                }
                .foregroundStyle(talkStore.canStartSession ? Design.Colors.background : Design.Colors.mutedForeground)
                .padding(.horizontal, Design.Spacing.md)
                .padding(.vertical, Design.Spacing.md)
                .frame(maxWidth: .infinity)
                .background(talkStore.canStartSession ? Design.Brand.accent : Design.Colors.background.opacity(0.5),
                            in: RoundedRectangle(cornerRadius: Design.CornerRadius.md))
            }
            .buttonStyle(.plain)
            .disabled(!talkStore.canStartSession)

            if let status = talkStore.statusMessage, !status.isEmpty {
                Text(status)
                    .font(Design.Typography.caption)
                    .foregroundStyle(Design.Colors.secondaryForeground)
                    .padding(.horizontal, Design.Spacing.xxs)
            }
        }
    }

    // MARK: Row + helpers

    private func statusRow(_ label: String, value: String, color: Color) -> some View {
        HStack(spacing: Design.Spacing.sm) {
            StatusPip(color: color, diameter: 7)
            Text(label)
                .font(Design.Typography.callout)
                .foregroundStyle(Design.Colors.foreground)
            Spacer(minLength: Design.Spacing.xs)
            MonoLabel(value, size: 9, weight: .medium, tracking: Design.Tracking.mono, color: color)
                .lineLimit(1)
        }
        .padding(.horizontal, Design.Spacing.md)
        .padding(.vertical, Design.Spacing.sm)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Design.Colors.cyanHairline)
            .frame(height: 1)
            .padding(.horizontal, Design.Spacing.md)
    }

    private func tone(_ known: Bool) -> Color {
        known ? Design.Brand.accent : Design.Colors.mutedForeground
    }

    private func fmtMs(_ t: TimeInterval?) -> String {
        guard let t else { return "—" }
        if t < 1 { return "\(Int((t * 1000).rounded())) ms" }
        return String(format: "%.2f s", t)
    }

    private func fmtDate(_ d: Date?) -> String {
        guard let d else { return "—" }
        return d.formatted(date: .abbreviated, time: .shortened)
    }

    private func refresh() async {
        isRefreshing = true
        await talkStore.refreshReadiness()
        isRefreshing = false
    }
}
