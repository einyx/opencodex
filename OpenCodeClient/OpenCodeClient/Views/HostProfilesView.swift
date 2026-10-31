import Observation
import SwiftUI

struct CurrentHostSummaryView: View {
    @Bindable var state: AppState

    var body: some View {
        let profile = state.currentHostProfile
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(profile?.displayName ?? L10n.t(.hostNoHost))
                    .font(.headline)
                Spacer()
                Text(profile?.transport.label ?? "")
                    .font(.caption)
                    .foregroundStyle(DesignColors.Brand.primary)
            }
            Text(profile?.connectionSummary ?? L10n.t(.hostAddToConnect))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack {
                if state.isConnected {
                    Label(L10n.t(.settingsConnected), systemImage: "checkmark.circle")
                } else {
                    Label(L10n.t(.settingsDisconnected), systemImage: "xmark.circle")
                }
                Spacer()
                if let version = state.serverVersion {
                    Text(version)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// The hand-drawn pairing scene: the invitation to connect a server.
///
/// It is decorative, so VoiceOver skips it. It means "nothing here yet" —
/// a real load keeps using `ProgressView`.
private struct PairingArtwork: View {
    var body: some View {
        Image("PairingArt")
            .resizable()
            .scaledToFit()
            .frame(width: 140, height: 140)
            .accessibilityHidden(true)
    }
}

struct HostProfilesView: View {
    @Bindable var state: AppState
    @State private var editorMode: HostProfileEditorMode?
    @State private var publicKeyCopied = false
    @State private var errorMessage: String?
    @State private var showRotateKeyAlert = false

    var body: some View {
        Form {
            if state.currentHostProfile != nil {
                // Connection status only — the host's name and URL already
                // appear once in the Hosts list below, on the selected row.
                Section(L10n.t(.settingsConnection)) {
                    CurrentHostCard(state: state, profile: state.currentHostProfile!)
                        .accessibilityIdentifier("hosts-connection-card")
                }
            }

            Section {
                ForEach(state.hostProfiles) { profile in
                    NavigationLink {
                        HostProfileDetailView(state: state, profileID: profile.id) { selected in
                            editorMode = .edit(selected)
                        }
                    } label: {
                        HostProfileRow(state: state, profile: profile)
                    }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                do {
                                    try state.deleteHostProfile(profile)
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            } label: {
                                Label(L10n.t(.hostDelete), systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                state.duplicateHostProfile(profile)
                            } label: {
                                Label(L10n.t(.hostDuplicate), systemImage: "plus.square.on.square")
                            }
                            .tint(.gray)
                        }
                        .contextMenu {
                            Button(L10n.t(.hostEdit)) { editorMode = .edit(profile) }
                            Button(L10n.t(.hostDuplicate)) { state.duplicateHostProfile(profile) }
                            Button(L10n.t(.hostDelete), role: .destructive) {
                                do { try state.deleteHostProfile(profile) } catch { errorMessage = error.localizedDescription }
                            }
                        }
                }

                if state.hostProfiles.isEmpty {
                    // Nothing here yet: the drawing invites the first host and
                    // the "Add Host" button under it is the action it points
                    // at. It is not a loading state — nothing is in flight.
                    VStack(spacing: DesignSpacing.sm) {
                        PairingArtwork()
                        Text(L10n.t(.hostNoHost))
                            .font(DesignTypography.headline)
                            .foregroundStyle(DesignColors.Neutral.text)
                        Text(L10n.t(.hostAddToConnect))
                            .font(DesignTypography.meta)
                            .foregroundStyle(DesignColors.Neutral.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSpacing.md)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("hosts-empty-state")
                }

                Button {
                    editorMode = .add
                } label: {
                    Label(L10n.t(.hostAdd), systemImage: "plus.circle")
                }
                .accessibilityIdentifier("hosts-add-host")
            } header: {
                Text(L10n.t(.hostHosts))
            } footer: {
                Text(L10n.t(.hostCurrentFooter))
            }

            #if !os(visionOS)
            Section(L10n.t(.hostDeviceKey)) {
                Button {
                    copyPublicKey()
                } label: {
                    Label(publicKeyCopied ? L10n.t(.settingsPublicKeyCopied) : L10n.t(.hostCopyDevicePublicKey), systemImage: publicKeyCopied ? "checkmark" : "doc.on.doc")
                }
                .accessibilityIdentifier("hosts-copy-device-public-key")
                Button(role: .destructive) {
                    showRotateKeyAlert = true
                } label: {
                    Label(L10n.t(.settingsPublicKeyRotate), systemImage: "arrow.triangle.2.circlepath")
                }
                .accessibilityIdentifier("hosts-rotate-device-public-key")
                Text(L10n.t(.hostDeviceKeyFooter))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #endif
        }
        .navigationTitle(L10n.t(.hostHosts))
        .dismissableKeyboard()
        .onAppear {
            guard UITestFixtures.hasHostEditorCredentialFixture, editorMode == nil else { return }
            guard let profile = state.currentHostProfile ?? state.hostProfiles.first else { return }
            editorMode = .edit(profile)
        }
        .overlay(alignment: .bottomTrailing) {
            if UITestFixtures.hasHostEditorCredentialFixture {
                HostCredentialRecordSentinel()
                    .padding(.trailing, 12)
                    .padding(.bottom, 8)
                    .allowsHitTesting(false)
            }
        }
        .sheet(item: $editorMode) { mode in
            if UITestFixtures.hasHostEditorCredentialFixture {
                HostEditorParentRebuildProbe(state: state, mode: mode)
            } else {
                HostProfileEditorView(state: state, mode: mode)
            }
        }
        .alert(L10n.t(.hostErrorTitle), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L10n.t(.commonOk), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(L10n.t(.settingsRotateKeyTitle), isPresented: $showRotateKeyAlert) {
            Button(L10n.t(.commonCancel), role: .cancel) {}
            Button(L10n.t(.settingsRotate), role: .destructive) {
                rotatePublicKey()
            }
        } message: {
            Text(L10n.t(.settingsRotateKeyPrompt))
        }
        .alert(
            L10n.t(.settingsTrustHostKeyTitle),
            isPresented: Binding(
                get: { state.pendingSSHHostKeyMismatch != nil },
                set: { if !$0 { state.dismissPendingSSHHostKeyMismatch() } }
            ),
            presenting: state.pendingSSHHostKeyMismatch
        ) { _ in
            Button(L10n.t(.commonCancel), role: .cancel) {
                state.dismissPendingSSHHostKeyMismatch()
            }
            Button(L10n.t(.settingsTrustHostKeyConfirm)) {
                Task { await state.trustPendingSSHHostKeyAndReconnect() }
            }
        } message: { mismatch in
            Text(L10n.t(
                .settingsTrustHostKeyMessage,
                mismatch.host,
                mismatch.port,
                mismatch.expectedFingerprint,
                mismatch.presentedFingerprint
            ))
        }
    }

    private func copyPublicKey() {
        #if !os(visionOS)
        do {
            let key = try state.sshTunnelManager.readPublicKey()
            UIPasteboard.general.string = key
            publicKeyCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { publicKeyCopied = false }
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }

    private func rotatePublicKey() {
        #if !os(visionOS)
        do {
            let key = try state.sshTunnelManager.rotateKey()
            UIPasteboard.general.string = key
            publicKeyCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { publicKeyCopied = false }
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }
}

struct HostCardStatus: Equatable {
    var diagnostic: ConnectionDiagnostic?
    var storageError: String?
    var connectionError: String?
}

func hostCardStatus(
    profileID: UUID,
    diagnostic: ConnectionDiagnostic?,
    loadError: String?,
    credentialError: String?,
    connectionError: String?
) -> HostCardStatus {
    let matching = diagnostic?.hostProfileID == profileID ? diagnostic : nil
    return HostCardStatus(
        diagnostic: matching,
        storageError: loadError ?? credentialError,
        connectionError: matching == nil ? connectionError : nil
    )
}

private struct CurrentHostCard: View {
    @Bindable var state: AppState
    let profile: HostProfile

    var body: some View {
        let status = hostCardStatus(
            profileID: profile.id,
            diagnostic: state.connectionDiagnostic,
            loadError: state.hostProfileLoadError,
            credentialError: state.hostCredentialError,
            connectionError: state.connectionError
        )
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                // One status signal per card: when a diagnostic summary is
                // visible below, its phase row already states connected /
                // disconnected, so the static row would repeat it three ways.
                if status.diagnostic == nil {
                    Group {
                        if state.isConnected {
                            Label(L10n.t(.settingsConnected), systemImage: "checkmark.circle")
                        } else {
                            Label(L10n.t(.settingsDisconnected), systemImage: "xmark.circle")
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button(L10n.t(.settingsTestConnection)) {
                    Task { await state.refresh() }
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignColors.Brand.primary)
            }
            .font(.caption)
            if let diagnostic = status.diagnostic {
                DiagnosticSummaryView(diagnostic: diagnostic)
            }
            if let storageError = status.storageError {
                Text(storageError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let connectionError = status.connectionError {
                Text(connectionError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DiagnosticSummaryView: View {
    let diagnostic: ConnectionDiagnostic

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: DesignSpacing.sm) {
                if diagnostic.phase.isChecking {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                    Text(diagnostic.phase.label)
                } else {
                    Label(diagnostic.phase.label, systemImage: diagnostic.phase.diagnosticSymbol)
                }
            }
                .font(.caption)
                .foregroundStyle(diagnostic.phase == .failed ? DesignColors.Semantic.error : DesignColors.Neutral.textSecondary)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("host-connection-phase")
                .accessibilityLabel(diagnostic.phase.label)
                .accessibilityValue(diagnostic.phase.label)
            Text(diagnostic.message)
                .font(.caption)
                .foregroundStyle(diagnostic.phase == .failed ? DesignColors.Semantic.error : DesignColors.Neutral.textSecondary)
                .accessibilityIdentifier("host-connection-diagnostic")
            if let recoveryHint = diagnostic.recoveryHint {
                Text(recoveryHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct HostProfileRow: View {
    @Bindable var state: AppState
    let profile: HostProfile

    private var isCurrent: Bool { profile.id == state.currentHostProfileID }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isCurrent ? DesignColors.Brand.primary : Color.clear)
                .frame(width: 3, height: 42)
            Image(systemName: profile.transport == .sshTunnel ? "terminal" : "network")
                .frame(width: 24)
                .foregroundStyle(isCurrent ? DesignColors.Brand.primary : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.displayName)
                    .foregroundStyle(.primary)
                Text(profile.connectionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(lastUsedText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if isCurrent {
                Image(systemName: "checkmark")
                    .foregroundStyle(DesignColors.Brand.primary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("host-profile-\(profile.id.uuidString)")
    }

    private var lastUsedText: String {
        guard let lastUsedAt = profile.lastUsedAt,
              lastUsedAt.timeIntervalSince1970 > 60 * 60 * 24 * 365 else {
            return L10n.t(.hostNeverConnected)
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = L10n.currentLocale
        formatter.unitsStyle = .abbreviated
        return L10n.t(.hostLastUsed, formatter.localizedString(for: lastUsedAt, relativeTo: Date()))
    }
}

private struct HostProfileDetailView: View {
    @Bindable var state: AppState
    let profileID: UUID
    let onEdit: (HostProfile) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var copiedHostConfig = false
    @State private var copiedPublicKey = false
    @State private var errorMessage: String?

    private var profile: HostProfile? {
        state.hostProfiles.first { $0.id == profileID }
    }

    private var isCurrent: Bool {
        profileID == state.currentHostProfileID
    }

    var body: some View {
        Form {
            if UITestFixtures.hasHostEditorCredentialFixture {
                HostCredentialRecordSentinel()
            }
            if Tier4OfflineFixture.isActive {
                Tier4CredentialSentinel()
            }
            if let profile {
                Section(L10n.t(.hostOverview)) {
                    LabeledContent(L10n.t(.hostName), value: profile.displayName)
                    LabeledContent(L10n.t(.hostTransport), value: profile.transport.label)
                    LabeledContent(L10n.t(.hostOpenCodeURL), value: profile.transport == .sshTunnel ? L10n.t(.hostManagedBySSHTunnel) : profile.serverURL)
                    LabeledContent(L10n.t(.hostStatus), value: isCurrent ? L10n.t(.hostCurrent) : L10n.t(.hostSavedHost))
                }
                .accessibilityIdentifier("host-detail-overview")

                if profile.transport == .sshTunnel, let ssh = profile.ssh {
                    Section(L10n.t(.hostSSHGateway)) {
                        HostDetailField(title: L10n.t(.hostGatewayHost), value: ssh.host, accessibilityID: "host-detail-ssh-host")
                        HostDetailField(title: L10n.t(.hostSSHPort), value: String(ssh.port), accessibilityID: "host-detail-ssh-port")
                        HostDetailField(title: L10n.t(.hostSSHUsername), value: ssh.username, accessibilityID: "host-detail-ssh-username")
                        HostDetailField(title: L10n.t(.hostAssignedRemotePort), value: String(ssh.remotePort), accessibilityID: "host-detail-ssh-remote-port")
                    }
                    .accessibilityIdentifier("host-detail-ssh-gateway")
                }

                if let diagnostic = state.connectionDiagnostic, diagnostic.hostProfileID == profile.id {
                    Section(L10n.t(.hostConnectionDiagnostics)) {
                        DiagnosticSummaryView(diagnostic: diagnostic)
                    }
                    .accessibilityIdentifier("host-detail-diagnostics")
                }

                Section {
                    if !isCurrent {
                        Button(L10n.t(.hostUseThisHost)) {
                            Task {
                                await state.switchHostProfile(to: profile.id)
                                dismiss()
                            }
                        }
                        .accessibilityIdentifier("host-detail-use-this-host")
                    }
                    Button(L10n.t(isCurrent ? .settingsTestConnection : .hostConnect)) {
                        if !isCurrent {
                            Task {
                                await state.switchHostProfile(to: profile.id)
                                await state.refresh()
                            }
                        } else {
                            Task { await state.refresh() }
                        }
                    }
                    Button(L10n.t(.hostEdit)) { onEdit(profile) }
                        .accessibilityIdentifier("host-detail-edit")
                    Button(copiedHostConfig ? L10n.t(.hostConfigCopied) : L10n.t(.hostCopyConfigJSON)) {
                        copyHostConfig(profile)
                    }
                    .accessibilityIdentifier("host-detail-copy-config")
                    #if !os(visionOS)
                    if profile.transport == .sshTunnel {
                        Button(copiedPublicKey ? L10n.t(.settingsPublicKeyCopied) : L10n.t(.hostCopyDevicePublicKey)) {
                            copyPublicKey()
                        }
                        .accessibilityIdentifier("host-detail-copy-device-public-key")
                    }
                    #endif
                }
            } else {
                Text(L10n.t(.hostNotFound))
            }
        }
        .navigationTitle(profile?.displayName ?? L10n.t(.hostTitle))
        .dismissableKeyboard()
        .alert(L10n.t(.hostErrorTitle), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L10n.t(.commonOk), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func copyHostConfig(_ profile: HostProfile) {
        do {
            let json = try state.hostConfigJSON(for: profile)
            #if !os(visionOS)
            UIPasteboard.general.string = json
            #endif
            copiedHostConfig = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedHostConfig = false }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyPublicKey() {
        #if !os(visionOS)
        do {
            UIPasteboard.general.string = try state.sshTunnelManager.readPublicKey()
            copiedPublicKey = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedPublicKey = false }
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }
}

private struct HostDetailField: View {
    let title: String
    let value: String
    let accessibilityID: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityID)
    }
}

enum HostProfileEditorMode: Identifiable {
    case add
    case edit(HostProfile)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let profile): return profile.id.uuidString
        }
    }
}

@Observable
final class HostEditorCredentialDraft {
    var password: String
    var passwordDirty = false
    var passwordLoadFailed: Bool
    var errorMessage: String?

    init(password: String, loadFailed: Bool, errorMessage: String?) {
        self.password = password
        self.passwordLoadFailed = loadFailed
        self.errorMessage = errorMessage
    }
}

struct HostProfileEditorView: View {
    @Bindable var state: AppState
    let mode: HostProfileEditorMode
    @Environment(\.dismiss) private var dismiss

    @State private var profile: HostProfile
    @State private var savedProfile: HostProfile
    @State private var showDiscardConfirmation = false
    @State private var showImport = false
    @State var credentialDraft: HostEditorCredentialDraft
    @State private var importText = ""
    @State private var publicKeyCopied = false
    /// The pairing link pasted or scanned by the user.
    @State private var pairingLinkText = ""
    /// The host a successful pairing produced, shown as a confirmation.
    @State private var pairedHostName: String?
    /// The pairing code that was already redeemed.
    @State private var lastRedeemedCode: String?
    @State private var isPairing = false
    /// The pending auto-redeem, cancelled when the link changes again.
    ///
    /// The link is redeemed when the typing settles: a link that is still
    /// being typed is not a link yet, and every attempt would spend the
    /// single-use code.
    @State private var pendingPairingRedeem: Task<Void, Never>?
    /// A redeemed pairing that would replace the address of a host that
    /// already has one. It waits for an explicit confirmation.
    @State private var pendingPairingReplacement: PairingReplacement?
    #if os(iOS)
    @State private var isScanningQR = false
    #endif

    /// The pairing state the UI renders.
    private var pairingState: PairingState {
        isPairing ? .busy : .idle
    }

    private enum PairingState {
        case idle
        case busy

        var isBusy: Bool {
            if case .busy = self { return true }
            return false
        }
    }

    /// Redeem a pairing link and fill the host with its address and token.
    ///
    /// The token is a session token: it is accepted anywhere the server
    /// password is, so it becomes the host's Basic-auth password with the
    /// username `opencode`.
    private func redeemPairingLink(_ value: String) async {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let link = PairingLink.parse(trimmed) else {
            credentialDraft.errorMessage = L10n.t(.hostPairInvalidLink)
            return
        }
        await redeem(link)
    }

    /// Redeem an already parsed pairing link.
    private func redeem(_ link: PairingLink) async {
        guard !pairingState.isBusy else { return }
        // The code is single-use: redeeming it twice would report the first
        // success as an expiry.
        guard link.code != lastRedeemedCode else { return }
        isPairing = true
        defer { isPairing = false }
        do {
            let pairing = try await PairingClient().redeem(link)
            lastRedeemedCode = link.code
            // A scanned code names the server it belongs to. Replacing the
            // address of a host that already has one is a decision the user
            // has to make: a hostile code must not silently repoint a host
            // that is called something else.
            if PairingReplacementPolicy.needsConfirmation(
                currentURL: profile.serverURL,
                pairedURL: pairing.url
            ) {
                pendingPairingReplacement = PairingReplacement(
                    previousURL: profile.serverURL.trimmingCharacters(in: .whitespacesAndNewlines),
                    url: pairing.url,
                    token: pairing.token
                )
                return
            }
            applyPairing(url: pairing.url, token: pairing.token)
        } catch {
            credentialDraft.errorMessage = error.localizedDescription
        }
    }

    /// Apply a redeemed pairing to the profile being edited.
    private func applyPairing(url: String, token: String) {
        profile.transport = .direct
        profile.serverURL = url
        profile.basicAuth = BasicAuthConfig(
            username: "opencode",
            keychainPasswordID: AppState.passwordKeychainID(for: profile.id)
        )
        profile.apiGeneration = .v2
        pairingLinkText = ""
        pairedHostName = url
        credentialDraft.password = token
        credentialDraft.passwordDirty = true
    }

    /// A pairing that wants to replace the address of an existing host.
    private struct PairingReplacement: Identifiable {
        let previousURL: String
        let url: String
        let token: String
        var id: String { url }
    }

    init(state: AppState, mode: HostProfileEditorMode) {
        self.state = state
        self.mode = mode
        let initial: HostProfile
        switch mode {
        case .add:
            initial = HostProfile(name: "", transport: .direct, serverURL: "", basicAuth: nil, ssh: nil)
        case .edit(let profile):
            initial = profile
        }
        let loadedPassword: String
        let loadError: String?
        if let auth = initial.basicAuth {
            do {
                loadedPassword = try state.hostCredentialAccess.load(auth.keychainPasswordID) ?? ""
                loadError = nil
            } catch {
                loadedPassword = ""
                loadError = error.localizedDescription
                state.hostCredentialError = error.localizedDescription
            }
        } else {
            loadedPassword = ""
            loadError = nil
        }
        _profile = State(initialValue: initial)
        _savedProfile = State(initialValue: initial)
        _credentialDraft = State(initialValue: HostEditorCredentialDraft(
            password: loadedPassword,
            loadFailed: loadError != nil,
            errorMessage: loadError
        ))
        _importText = State(initialValue: Self.uiTestImportJSON)
    }

    var body: some View {
        NavigationStack {
            Form {
                if case .add = mode, showImport {
                    Section {
                        TextEditor(text: $importText)
                            .frame(minHeight: 80)
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("host-import-json")
                            .accessibilityLabel(L10n.t(.hostManualImport))
                        Button {
                            do {
                                profile = try state.importHostProfile(from: importText)
                                importText = ""
                            } catch {
                                credentialDraft.errorMessage = error.localizedDescription
                            }
                        } label: {
                            Label(L10n.t(.hostImportConfig), systemImage: "square.and.arrow.down")
                        }
                        .accessibilityIdentifier("host-import-config")
                        .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } footer: {
                        Text(L10n.t(.hostImportFooter))
                    }
                }

                Section {
                    // The drawing is the invitation and the scan button under
                    // it is the point. It steps aside once a pairing landed:
                    // the confirmation label says it for itself.
                    if pairedHostName == nil {
                        PairingArtwork()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSpacing.sm)
                    }
                    #if os(iOS)
                    Button {
                        isScanningQR = true
                    } label: {
                        Label(L10n.t(.hostPairScanQR), systemImage: "qrcode.viewfinder")
                    }
                    .accessibilityIdentifier("host-pair-scan-qr")
                    .disabled(pairingState.isBusy)
                    #endif

                    if case .add = mode {
                        Button(L10n.t(.hostManualImport)) { showImport.toggle() }
                    }

                    HStack {
                        TextField(L10n.t(.hostPairLinkPlaceholder), text: $pairingLinkText)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("host-pair-link-field")
                            .onChange(of: pairingLinkText) { _, value in
                                // A pasted pairing link is redeemed on the
                                // spot: the credentials come from the link,
                                // so there is nothing else to type. A link
                                // that is typed in is redeemed once the
                                // typing settles.
                                pendingPairingRedeem?.cancel()
                                guard let link = PairingLink.parse(value) else { return }
                                pendingPairingRedeem = Task {
                                    try? await Task.sleep(for: .milliseconds(400))
                                    guard !Task.isCancelled else { return }
                                    await redeem(link)
                                }
                            }
                        Button {
                            Task { await redeemPairingLink(pairingLinkText) }
                        } label: {
                            if pairingState.isBusy {
                                ProgressView()
                            } else {
                                Image(systemName: "link")
                            }
                        }
                        .accessibilityIdentifier("host-pair-link-redeem")
                        .accessibilityLabel(L10n.t(.hostPairSection))
                        .disabled(pairingLinkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pairingState.isBusy)
                    }

                    if let paired = pairedHostName {
                        Label(L10n.t(.hostPairPaired, paired), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(DesignColors.Brand.primary)
                            .accessibilityIdentifier("host-pair-paired")
                    }
                } header: {
                    Text(L10n.t(.hostPairSection))
                } footer: {
                    Text(L10n.t(.hostPairCameraHint))
                }

                Section {
                    Picker(L10n.t(.hostConnectionType), selection: $profile.transport) {
                        ForEach(HostTransport.allCases) { transport in
                            Text(transport.label).tag(transport)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("host-transport-picker")
                    .onChange(of: profile.transport) { _, newValue in
                        if newValue == .sshTunnel {
                            profile.serverURL = APIClient.defaultServer
                            if profile.ssh == nil { profile.ssh = .default }
                        } else {
                            profile.ssh = nil
                        }
                    }
                } footer: {
                    Text(L10n.t(.hostTransportFooter))
                }

                Section(L10n.t(.hostTitle)) {
                    TextField(L10n.t(.hostName), text: nameBinding)
                        .accessibilityIdentifier("host-name")
                    if profile.transport == .direct {
                        TextField(L10n.t(.hostOpenCodeURL), text: $profile.serverURL)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("host-server-url")
                    } else {
                        LabeledContent(L10n.t(.hostOpenCodeURL)) {
                            Text(L10n.t(.hostManagedBySSHTunnel))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if profile.transport == .sshTunnel {
                    Section {
                        TextField(L10n.t(.hostGatewayHost), text: sshHostBinding)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("host-ssh-gateway")
                        LabeledNumberField(title: L10n.t(.hostSSHPort), value: sshPortBinding, accessibilityID: "host-ssh-port")
                        TextField(L10n.t(.hostSSHUsername), text: sshUsernameBinding)
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("host-ssh-username")
                        LabeledNumberField(title: L10n.t(.hostAssignedRemotePort), value: sshRemotePortBinding, accessibilityID: "host-ssh-remote-port")
                    } header: {
                        Text(L10n.t(.hostSSHGateway))
                    } footer: {
                        Text(L10n.t(.hostSSHGatewayFooter))
                    }
                    .accessibilityIdentifier("host-ssh-gateway-section")

                    #if !os(visionOS)
                    Section(L10n.t(.hostDeviceKey)) {
                        Button {
                            copyPublicKey()
                        } label: {
                            Label(publicKeyCopied ? L10n.t(.settingsPublicKeyCopied) : L10n.t(.hostCopyDevicePublicKey), systemImage: publicKeyCopied ? "checkmark" : "doc.on.doc")
                        }
                        .accessibilityIdentifier("host-editor-copy-device-public-key")
                        Text(L10n.t(.hostDeviceKeySendFooter))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    #endif
                }

                // A pairing link supplies the credentials, so they are not
                // asked for again.
                if pairedHostName == nil {
                    Section(L10n.t(.hostBasicAuth)) {
                        TextField(L10n.t(.settingsUsername), text: basicAuthUsernameBinding)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("host-username")
                        SecureField(L10n.t(.settingsPassword), text: passwordBinding)
                            .textContentType(.password)
                            .accessibilityIdentifier("host-password")
                            .modifier(HostEditorPasswordProbe(password: credentialDraft.password))
                    }
                }

                Section {
                    Button(L10n.t(.hostSaveAndConnect)) {
                        if save(makeCurrent: true) {
                            Task { await state.refresh() }
                        }
                    }
                    .disabled(!canSave)
                    Text(L10n.t(.hostSaveHelp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(isEditing ? L10n.t(.hostEditTitle) : L10n.t(.hostAddTitle))
            .dismissableKeyboard()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t(.commonCancel)) {
                        if hasUnsavedChanges { showDiscardConfirmation = true }
                        else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t(.hostSave)) {
                        if save(makeCurrent: true) {
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("host-save")
                }
            }
            .alert(L10n.t(.hostErrorTitle), isPresented: Binding(
                get: { credentialDraft.errorMessage != nil },
                set: { if !$0 { credentialDraft.errorMessage = nil } }
            )) {
                Button(L10n.t(.commonOk), role: .cancel) {}
            } message: {
                Text(credentialDraft.errorMessage ?? "")
            }
            .confirmationDialog(L10n.t(.hostDiscardTitle), isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
                Button(L10n.t(.hostDiscardChanges), role: .destructive) { dismiss() }
                // No role on the second button: with `role: .cancel` the
                // dialog sizes itself for one button and the second one
                // falls off the bottom, out of reach.
                Button(L10n.t(.hostKeepEditing)) {}
            } message: {
                // The message is never empty: an empty one leaves the dialog
                // a button short, and "Keep Editing" falls off the bottom.
                if lastRedeemedCode != nil || isPairing {
                    Text(L10n.t(.hostDiscardPairingWarning))
                } else {
                    Text(L10n.t(.hostDiscardChangesWarning))
                }
            }
            .alert(L10n.t(.hostPairReplaceTitle), isPresented: Binding(
                get: { pendingPairingReplacement != nil },
                set: { if !$0 { pendingPairingReplacement = nil } }
            )) {
                Button(L10n.t(.commonCancel), role: .cancel) {
                    pendingPairingReplacement = nil
                }
                Button(L10n.t(.hostPairReplaceConfirm)) {
                    guard let replacement = pendingPairingReplacement else { return }
                    pendingPairingReplacement = nil
                    applyPairing(url: replacement.url, token: replacement.token)
                }
            } message: {
                if let replacement = pendingPairingReplacement {
                    Text(L10n.t(.hostPairReplaceMessage, replacement.url, replacement.previousURL))
                }
            }
            #if os(iOS)
            .sheet(isPresented: $isScanningQR) {
                QRScannerView { payload in
                    isScanningQR = false
                    pairingLinkText = payload
                    guard let link = PairingLink.parse(payload) else {
                        credentialDraft.errorMessage = L10n.t(.hostPairInvalidLink)
                        return
                    }
                    Task { await redeem(link) }
                }
            }
            #endif
        }
        .interactiveDismissDisabled(hasUnsavedChanges || isPairing)
        .onAppear {
            if !importText.isEmpty { showImport = true }
        }
        .onDisappear { pendingPairingRedeem?.cancel() }
    }

    var hasUnsavedChanges: Bool {
        profile != savedProfile || credentialDraft.passwordDirty
            || !importText.isEmpty || !pairingLinkText.isEmpty || isPairing
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private static var uiTestImportJSON: String {
        guard ProcessInfo.processInfo.arguments.contains("UITEST_HOST_IMPORT_JSON_PREFILL") else { return "" }
        return #"{"version":1,"name":"Imported SSH","transport":"sshTunnel","ssh":{"host":"gateway.example.invalid","port":8006,"username":"opencode","remotePort":19001}}"#
    }

    private var canSave: Bool {
        let nameOK = !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch profile.transport {
        case .direct:
            return nameOK && !profile.serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .sshTunnel:
            return nameOK && (profile.ssh?.isValid ?? false)
        }
    }

    private var basicAuthUsernameBinding: Binding<String> {
        Binding {
            profile.basicAuth?.username ?? ""
        } set: { newValue in
            if newValue.isEmpty && credentialDraft.password.isEmpty && !credentialDraft.passwordLoadFailed {
                profile.basicAuth = nil
            } else {
                let passwordID = profile.basicAuth?.keychainPasswordID ?? AppState.passwordKeychainID(for: profile.id)
                profile.basicAuth = BasicAuthConfig(username: newValue, keychainPasswordID: passwordID)
            }
        }
    }

    private var nameBinding: Binding<String> {
        Binding(get: { profile.name }, set: { editName($0) })
    }

    private var passwordBinding: Binding<String> {
        Binding(get: { credentialDraft.password }, set: { editPassword($0) })
    }

    var errorMessage: String? { credentialDraft.errorMessage }

    var passwordDirty: Bool { credentialDraft.passwordDirty }
    var passwordLoadFailed: Bool { credentialDraft.passwordLoadFailed }

    func editName(_ name: String) {
        profile.name = name
    }

    func editPassword(_ value: String) {
        credentialDraft.password = value
        credentialDraft.passwordDirty = true
    }

    private var sshHostBinding: Binding<String> {
        Binding { profile.ssh?.host ?? "" } set: { updateSSH { $0.host = $1 }($0) }
    }

    private var sshUsernameBinding: Binding<String> {
        Binding { profile.ssh?.username ?? "opencode" } set: { updateSSH { $0.username = $1 }($0) }
    }

    private var sshPortBinding: Binding<Int> {
        Binding { profile.ssh?.port ?? 8006 } set: { newValue in updateSSH { $0.port = newValue } }
    }

    private var sshRemotePortBinding: Binding<Int> {
        Binding { profile.ssh?.remotePort ?? 19001 } set: { newValue in updateSSH { $0.remotePort = newValue } }
    }

    private func updateSSH(_ edit: (inout SSHTunnelConfig) -> Void) {
        var ssh = profile.ssh ?? .default
        ssh.isEnabled = true
        edit(&ssh)
        profile.ssh = ssh
        profile.serverURL = APIClient.defaultServer
    }

    private func updateSSH(_ edit: @escaping (inout SSHTunnelConfig, String) -> Void) -> (String) -> Void {
        { value in
            var ssh = profile.ssh ?? .default
            ssh.isEnabled = true
            edit(&ssh, value)
            profile.ssh = ssh
            profile.serverURL = APIClient.defaultServer
        }
    }

    @discardableResult
    func save(makeCurrent: Bool) -> Bool {
        var toSave = profile
        if toSave.transport == .sshTunnel {
            var ssh = toSave.ssh ?? .default
            ssh.isEnabled = true
            toSave.ssh = ssh
            toSave.serverURL = APIClient.defaultServer
        }
        let passwordArgument: String? = credentialDraft.passwordDirty ? credentialDraft.password : nil
        do {
            try state.saveHostProfile(toSave, password: passwordArgument, makeCurrent: makeCurrent)
            profile = state.hostProfiles.first(where: { $0.id == toSave.id }) ?? toSave
            savedProfile = profile
            credentialDraft.passwordDirty = false
            return true
        } catch {
            credentialDraft.errorMessage = error.localizedDescription
            return false
        }
    }

    private func copyPublicKey() {
        #if !os(visionOS)
        do {
            let key = try state.sshTunnelManager.readPublicKey()
            UIPasteboard.general.string = key
            publicKeyCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { publicKeyCopied = false }
        } catch {
            credentialDraft.errorMessage = error.localizedDescription
        }
        #endif
    }
}

private struct HostCredentialRecordSentinel: View {
    var body: some View {
        let value = HostEditorCredentialFixture.record.committed
        Text(value)
            .font(.caption2)
            .accessibilityIdentifier("host-credential-record")
            .accessibilityValue(value)
    }
}

private struct HostEditorPasswordProbe: ViewModifier {
    let password: String

    func body(content: Content) -> some View {
        // UI-test-only echo of the SecureField contents. Compiled out of release
        // builds entirely: a launch-argument check alone would still let a
        // distributed binary publish the password into the accessibility tree.
        #if DEBUG
        if UITestFixtures.hasHostEditorCredentialFixture {
            content.accessibilityValue(password)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

private struct HostEditorParentRebuildProbe: View {
    @Bindable var state: AppState
    let mode: HostProfileEditorMode
    @State private var generation = 0

    var body: some View {
        HostProfileEditorView(state: state, mode: mode)
            .overlay(alignment: .topLeading) {
                if UITestFixtures.hasHostEditorRebuildFixture {
                    Button("Rebuild") { generation += 1 }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("editor-identity-rebuild")
                        .accessibilityLabel("g\(generation)")
                        .padding(.top, 64)
                        .padding(.leading, 12)
                }
            }
            .overlay(alignment: .bottomLeading) {
                HostCredentialRecordSentinel()
                    .padding(.leading, 12)
                    .padding(.bottom, 8)
                    .allowsHitTesting(false)
            }
    }
}

private struct LabeledNumberField: View {
    let title: String
    @Binding var value: Int
    let accessibilityID: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", value: $value, formatter: NumberFormatter())
                .accessibilityLabel(title)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                .accessibilityIdentifier(accessibilityID)
        }
    }
}
