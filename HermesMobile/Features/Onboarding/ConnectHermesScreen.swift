import SwiftUI

struct ConnectHermesScreen: View {
    @Environment(PairingStore.self) private var pairingStore

    @State private var setupCode = ""
    @State private var displayName = ""
    @State private var candidatePayload: RelaySetupCodePayload?
    @State private var candidateSetupCode: String?
    @State private var isScannerPresented = false
    @State private var isManualEntryVisible = false
    @State private var localErrorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case setupCode
        case displayName
    }

    var body: some View {
        ZStack {
            Design.Brand.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Design.Spacing.lg) {
                    heroSection

                    if let candidatePayload {
                        confirmationCard(payload: candidatePayload)
                    } else {
                        entryOptions

                        if isManualEntryVisible {
                            manualEntryCard
                        }
                    }

                    if let errorMessage {
                        errorCard(message: errorMessage)
                    }
                }
                .padding(.horizontal, Design.Spacing.md)
                .padding(.vertical, Design.Spacing.lg)
            }
        }
        .sheet(isPresented: $isScannerPresented) {
            scannerSheet
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sm) {
            Text("Connect Your Hermes")
                .font(Design.Typography.heroTitle)
                .foregroundStyle(Design.Brand.hermesCharcoal)

            Text("Pair this app with your own Hermes relay using a QR code or setup code generated on your Mac or server.")
                .font(Design.Typography.body)
                .foregroundStyle(.secondary)
        }
        .padding(Design.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Design.CornerRadius.xl))
    }

    private var entryOptions: some View {
        VStack(spacing: Design.Spacing.sm) {
            Button {
                localErrorMessage = nil
                isScannerPresented = true
            } label: {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    .font(Design.Typography.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .accessibilityLabel("Scan QR Code")

            Button {
                localErrorMessage = nil
                withAnimation(Design.Motion.standard) {
                    isManualEntryVisible = true
                }
                focusedField = .setupCode
            } label: {
                Label("Enter Setup Code", systemImage: "number")
                    .font(Design.Typography.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Enter Setup Code")
        }
    }

    private var manualEntryCard: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Text("Setup Code")
                .font(Design.Typography.sectionTitle)

            TextField("Paste setup code", text: $setupCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(Design.Typography.callout.monospaced())
                .padding(Design.Spacing.md)
                .background(Design.Brand.backgroundSecondary, in: RoundedRectangle(cornerRadius: Design.CornerRadius.lg))
                .focused($focusedField, equals: .setupCode)
                .accessibilityLabel("Setup code")

            Button("Continue") {
                previewSetupCode()
            }
            .buttonStyle(.glassProminent)
            .disabled(setupCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Continue setup code")
        }
        .padding(Design.Spacing.lg)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Design.CornerRadius.xl))
    }

    private func confirmationCard(payload: RelaySetupCodePayload) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Text("Confirm Relay")
                .font(Design.Typography.sectionTitle)

            hostRow(title: "Relay Host", value: payload.hostDisplayName)

            if let expiresAt = payload.expiresAt {
                hostRow(
                    title: "Expires",
                    value: expiresAt.formatted(date: .abbreviated, time: .shortened)
                )
            }

            TextField("Display name", text: $displayName)
                .textInputAutocapitalization(.words)
                .padding(Design.Spacing.md)
                .background(Design.Brand.backgroundSecondary, in: RoundedRectangle(cornerRadius: Design.CornerRadius.lg))
                .focused($focusedField, equals: .displayName)
                .accessibilityLabel("Display name")

            Button {
                Task { await completePairing() }
            } label: {
                if pairingStore.isWorking {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Connect Hermes")
                        .font(Design.Typography.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.glassProminent)
            .disabled(pairingStore.isWorking || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Connect Hermes")

            Button("Use a Different Code") {
                resetCandidate()
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Use a Different Code")
        }
        .padding(Design.Spacing.lg)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Design.CornerRadius.xl))
    }

    private var scannerSheet: some View {
        Group {
            if SetupCodeScannerView.isScannerAvailable {
                SetupCodeScannerView(
                    onCodeDetected: { code in
                        isScannerPresented = false
                        setupCode = code
                        previewSetupCode()
                    },
                    onFailure: { message in
                        isScannerPresented = false
                        localErrorMessage = message
                    }
                )
                .ignoresSafeArea()
            } else {
                ContentUnavailableView {
                    Label("Scanner Unavailable", systemImage: "qrcode.viewfinder")
                } description: {
                    Text("QR scanning is not available here. Use the setup code option instead.")
                } actions: {
                    Button("Use Setup Code") {
                        isScannerPresented = false
                        isManualEntryVisible = true
                        focusedField = .setupCode
                    }
                    .buttonStyle(.glassProminent)
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var errorMessage: String? {
        pairingStore.lastErrorMessage ?? localErrorMessage
    }

    private func previewSetupCode() {
        do {
            let payload = try pairingStore.decodeSetupCode(setupCode)
            candidatePayload = payload
            candidateSetupCode = setupCode.trimmingCharacters(in: .whitespacesAndNewlines)
            localErrorMessage = nil
            focusedField = .displayName
        } catch {
            localErrorMessage = error.localizedDescription
        }
    }

    private func completePairing() async {
        guard let candidateSetupCode else { return }
        let didPair = await pairingStore.pair(
            using: candidateSetupCode,
            displayName: displayName
        )
        if didPair {
            resetCandidate()
        }
    }

    private func resetCandidate() {
        candidatePayload = nil
        candidateSetupCode = nil
        localErrorMessage = nil
    }

    private func hostRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(Design.Typography.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Design.Typography.callout.monospaced())
        }
    }

    private func errorCard(message: String) -> some View {
        HStack(alignment: .top, spacing: Design.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(message)
                .font(Design.Typography.callout)
                .foregroundStyle(.primary)
        }
        .padding(Design.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Design.CornerRadius.lg))
    }
}
