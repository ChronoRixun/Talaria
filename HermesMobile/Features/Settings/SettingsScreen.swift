import SwiftUI

struct SettingsScreen: View {
    @Environment(AppSessionStore.self) private var sessionStore
    @Environment(HermesHostStore.self) private var hostStore
    @Environment(PairingStore.self) private var pairingStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(TabRouter.self) private var router

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Design.Spacing.lg) {
                    connectionSection
                    if settingsStore.availableEnvironments.count > 1 {
                        environmentSection
                    }
                    notificationsSection
                    privacySection
                    aboutSection
                }
                .padding(.horizontal, Design.Spacing.md)
                .padding(.vertical, Design.Spacing.sm)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
        .navigationTitle("Settings")
        .task {
            await hostStore.refresh()
        }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        @Bindable var settingsStore = settingsStore

        return SettingsSectionView(title: "Connection") {
            VStack(spacing: Design.Spacing.sm) {
                settingsRow(
                    icon: sessionStore.state.connectionStatus.displayIcon,
                    iconColor: sessionStore.state.connectionStatus.displayColor,
                    title: "Status",
                    subtitle: sessionStore.state.connectionStatus.displayLabel
                )

                if pairingStore.pairedRelayConfiguration != nil {
                    settingsRow(
                        icon: hostStore.isHostOnline ? "desktopcomputer" : "desktopcomputer.trianglebadge.exclamationmark",
                        iconColor: hostStore.isHostOnline ? .green : .orange,
                        title: "Hermes Host",
                        subtitle: hostStore.currentHost?.resolvedDisplayName ?? "Not Connected"
                    )

                    if let host = hostStore.currentHost {
                        settingsRow(
                            icon: "clock.arrow.circlepath",
                            iconColor: .secondary,
                            title: "Last Seen",
                            subtitle: host.lastSeenAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown"
                        )
                    }

                    Button {
                        router.navigate(to: .connectHost, in: .settings)
                    } label: {
                        HStack {
                            Label("Manage Hermes Host", systemImage: "desktopcomputer.and.arrow.down")
                                .font(Design.Typography.callout)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(Design.Typography.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: Design.Size.minTapTarget)
                    }
                }

                Toggle(isOn: $settingsStore.settings.autoConnectOnLaunch) {
                    Label("Auto-Connect on Launch", systemImage: "bolt.fill")
                        .font(Design.Typography.callout)
                }
                .tint(Design.Brand.accent)
            }
        }
    }

    // MARK: - Environment

    private var environmentSection: some View {
        SettingsSectionView(title: "Environment") {
            VStack(spacing: Design.Spacing.sm) {
                ForEach(settingsStore.availableEnvironments, id: \.self) { env in
                    Button {
                        withAnimation(Design.Motion.quickResponse) {
                            settingsStore.settings.environment = env
                        }
                    } label: {
                        HStack {
                            Text(env.displayLabel)
                                .font(Design.Typography.callout)
                                .foregroundStyle(.primary)

                            Spacer()

                            if settingsStore.settings.environment == env {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Design.Brand.accent)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(minHeight: Design.Size.minTapTarget)
                    }
                }

            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        @Bindable var settingsStore = settingsStore

        return SettingsSectionView(title: "Notifications") {
            VStack(spacing: Design.Spacing.sm) {
                Toggle(isOn: $settingsStore.settings.notificationsEnabled) {
                    Label("Push Notifications", systemImage: "bell.fill")
                        .font(Design.Typography.callout)
                }
                .tint(Design.Brand.accent)

                Toggle(isOn: $settingsStore.settings.hapticFeedbackEnabled) {
                    Label("Haptic Feedback", systemImage: "hand.tap.fill")
                        .font(Design.Typography.callout)
                }
                .tint(Design.Brand.accent)
            }
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        SettingsSectionView(title: "Privacy") {
            VStack(spacing: Design.Spacing.sm) {
                Button {
                    router.navigate(to: .permissions)
                } label: {
                    HStack {
                        Label("Permissions", systemImage: "lock.shield.fill")
                            .font(Design.Typography.callout)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(Design.Typography.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(minHeight: Design.Size.minTapTarget)
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        SettingsSectionView(title: "About") {
            VStack(spacing: Design.Spacing.sm) {
                settingsRow(icon: "info.circle", iconColor: .secondary, title: "Version", subtitle: "1.0.0 (1)")
                settingsRow(icon: "doc.text", iconColor: .secondary, title: "Terms of Service", subtitle: nil)
                settingsRow(icon: "hand.raised", iconColor: .secondary, title: "Privacy Policy", subtitle: nil)
            }
        }
    }

    // MARK: - Helpers

    private func settingsRow(icon: String, iconColor: Color, title: String, subtitle: String?) -> some View {
        HStack(spacing: Design.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: Design.Size.iconMedium)

            Text(title)
                .font(Design.Typography.callout)

            Spacer()

            if let subtitle {
                Text(subtitle)
                    .font(Design.Typography.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: Design.Size.minTapTarget)
    }
}
