//
//  AppState.swift
//  OpenCodeClient
//

import Foundation
import Observation
import os
#if os(iOS)
import UIKit
#endif

nonisolated struct SessionNode: Identifiable {
    let session: Session
    let children: [SessionNode]
    var id: String { session.id }
}

enum SessionIndicator {
    case needsYou, failed, running, unread
}

struct SessionIndicatorPresentation {
    var indicator: SessionIndicator?
    var needsSync: Bool
    var ownIsRetrying: Bool
    var activeDescendantCount: Int
    var ownIsActive: Bool = false

    var statusText: String? {
        let parts = [ownIsRetrying ? L10n.t(.sessionsStatusRetry) : nil,
                     needsSync ? SessionIndicatorCopy.syncing : nil].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var hasDetails: Bool { ownIsRetrying || needsSync || activeDescendantCount > 0 }
}

@Observable
@MainActor
final class AppState {
    static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "OpenCodeClient",
        category: "AppState"
    )

    struct ServerURLInfo {
        let raw: String
        let normalized: String?
        let scheme: String?
        let host: String?
        let isLocal: Bool
        /// Tailscale MagicDNS (*.ts.net) — ATS exception, HTTP allowed.
        let isTailscale: Bool
        let isAllowed: Bool
        let warning: String?
    }

    /// Ensures server URL has http:// or https:// prefix. Returns normalized string if missing scheme, nil otherwise.
    /// Call after correctMalformedServerURL. Ensures the stored/displayed value is explicit and avoids URL parsing quirks.
    nonisolated static func ensureServerURLHasScheme(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !trimmed.hasPrefix("http://"), !trimmed.hasPrefix("https://") else { return nil }
        return "http://\(trimmed)"
    }

    /// Fixes malformed "host://host:port" (e.g. from iOS .textContentType(.URL) autocorrect or paste).
    /// Returns corrected string if malformed, nil otherwise.
    nonisolated static func correctMalformedServerURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let idx = trimmed.range(of: "://") else { return nil }
        let beforeScheme = String(trimmed[..<idx.lowerBound])
        let afterScheme = String(trimmed[idx.upperBound...])
        // Case-insensitive: the duplicated-scheme quirk can carry the author's
        // casing ("HTTP://HTTP://host"), which a case-sensitive check misses.
        guard afterScheme.lowercased().hasPrefix(beforeScheme.lowercased()),
              beforeScheme.lowercased() != "http", beforeScheme.lowercased() != "https" else { return nil }
        return beforeScheme + afterScheme.dropFirst(beforeScheme.count)
    }

    /// LAN allows HTTP; WAN requires HTTPS.
    nonisolated static func serverURLInfo(_ raw: String) -> ServerURLInfo {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let corrected = Self.correctMalformedServerURL(trimmed) {
            trimmed = corrected
        }
        guard !trimmed.isEmpty else {
            return .init(raw: raw, normalized: nil, scheme: nil, host: nil, isLocal: true, isTailscale: false, isAllowed: false, warning: L10n.t(.errorServerAddressEmpty))
        }

        func parseHost(_ s: String) -> String? {
            if let u = URL(string: s), let h = u.host { return h }
            if let u = URL(string: "http://\(s)"), let h = u.host { return h }
            return nil
        }

        func isPrivateIPv4(_ host: String) -> Bool {
            let parts = host.split(separator: ".")
            guard parts.count == 4,
                  let a = Int(parts[0]), let b = Int(parts[1]) else { return false }
            if a == 10 || a == 127 { return true }
            if a == 192 && b == 168 { return true }
            if a == 172 && (16...31).contains(b) { return true }
            if a == 169 && b == 254 { return true }
            if host == "0.0.0.0" { return true }
            return false
        }

        // Scheme checks are case-insensitive: URL preserves the author's
        // casing ("HTTP://"), and a case-sensitive comparison would let an
        // uppercase plaintext address bypass the WAN/HTTPS requirement.
        let hasScheme: Bool = {
            guard let s = URL(string: trimmed)?.scheme?.lowercased() else { return false }
            return s == "http" || s == "https"
        }()
        let host = parseHost(trimmed)
        let isLocal: Bool = {
            guard let host else { return true }
            if host == "localhost" { return true }
            if host.hasSuffix(".local") { return true }
            if isPrivateIPv4(host) { return true }
            return false
        }()

        let scheme: String = {
            if let u = URL(string: trimmed), let s = u.scheme?.lowercased() { return s }
            return isLocal ? "http" : "https"
        }()

        let isTailscale = host?.hasSuffix(".ts.net") ?? false
        if scheme == "http", !isLocal, !isTailscale {
            return .init(
                raw: raw,
                normalized: hasScheme ? trimmed : nil,
                scheme: "http",
                host: host,
                isLocal: false,
                isTailscale: false,
                isAllowed: false,
                warning: L10n.t(.errorWanRequiresHttps)
            )
        }

        var normalized = hasScheme ? trimmed : "\(scheme)://\(trimmed)"
        while normalized.hasSuffix("/"), normalized.count > 8 {
            normalized.removeLast()
        }
        let parsed = URL(string: normalized)
        return .init(
            raw: raw,
            normalized: normalized,
            // Lowercased so consumers can compare schemes without re-doing the
            // case-insensitivity dance (URL preserves the author's casing).
            scheme: parsed?.scheme?.lowercased(),
            host: parsed?.host,
            isLocal: isLocal,
            isTailscale: isTailscale,
            isAllowed: parsed != nil,
            warning: parsed == nil ? L10n.t(.errorInvalidBaseURL) : (scheme == "http" && !isTailscale ? L10n.t(.errorUsingLanHttp) : nil)
        )
    }
    var _serverURL: String = APIClient.defaultServer
    var serverURL: String {
        get { _serverURL }
        set {
            _serverURL = newValue
            defaults.set(newValue, forKey: Self.serverURLKey)
        }
    }

    var _username: String = ""
    var username: String {
        get { _username }
        set {
            _username = newValue
            defaults.set(newValue, forKey: Self.usernameKey)
        }
    }

    var _password: String = ""
    var password: String {
        get { _password }
        set {
            _password = newValue
            if newValue.isEmpty {
                try? KeychainHelper.delete(Self.passwordKeychainKey)
            } else {
                try? KeychainHelper.save(newValue, forKey: Self.passwordKeychainKey)
            }
        }
    }

    static let serverURLKey = "serverURL"
    static let usernameKey = "username"
    static let passwordKeychainKey = "password"
    static let speechRecognitionEngineKey = "speechRecognitionEngine"
    nonisolated static let draftInputsBySessionKey = "draftInputsBySession"
    static let selectedModelBySessionKey = "selectedModelBySession"
    nonisolated static let draftInputsByHostKey = "draftInputsByHost.v1"
    static let selectedModelByHostKey = "selectedModelByHost.v1"
    static let selectedProjectWorktreeKey = "selectedProjectWorktree"
    static let customProjectPathKey = "customProjectPath"
    static let hostProfilesKey = "hostProfiles.v1"
    static let currentHostProfileIDKey = "currentHostProfileID.v1"
    static let aiUsageDashboardURLKey = "aiUsageDashboardURL"
    static let carModeEnabledKey = "carModeEnabled"
    static let layoutPreferenceKey = "layoutPreference"
    static let voiceFirstInputKey = "voiceFirstInput"
    static let composerActionSideKey = "composerActionSide"
    static let showImageAttachmentButtonKey = "showImageAttachmentButton"
    static let languagePreferenceKey = L10n.languagePreferenceUserDefaultsKey
    static let carSessionsByContextKey = "carSessionsByContext.v1"
    static let healthExportPermissionKey = "clientCapability.healthExportAll.permission.v1"
    static let agentExplicitlyChosenKey = "agentExplicitlyChosen.v1"
    /// The host-configuration signature captured when the user chose "Always
    /// Allow". The automatic grant is only honored for the exact host it was
    /// given to — a different (or reconfigured) host asks again. See
    /// `healthExportAutoAllowIsActive`.
    static let healthExportAllowAlwaysSignatureKey = "clientCapability.healthExportAll.allowAlwaysSignature.v1"
    static let modelShortlistKey = "modelShortlist.v1"

    init(
        apiClient: APIClientProtocol = APIClient(),
        sseClient: SSEClientProtocol = SSEClient(),
        sshTunnelManager: SSHTunnelManager? = nil,
        aiUsageQuotaClient: AIUsageQuotaClientProtocol? = nil,
        carSpeechOutput: CarSpeechOutputProviding? = nil,
        deviceVoice: DeviceVoiceEngine? = nil,
        deepLinkSessionResolver: ((String) async throws -> Session)? = nil,
        deepLinkHydratesSelection: Bool = true,
        clientCapabilityStore: ClientCapabilityCallbackStore = .applicationSupport(),
        clientCapabilityURLOpener: (@MainActor (URL) async -> Bool)? = nil,
        userDefaults: UserDefaults = .standard,
        hostCredentialAccess: HostCredentialAccess = .keychain
    ) {
        self.defaults = userDefaults
        self.sessionStore = SessionStore(defaults: userDefaults)
        // MessageStore persists finalized step timings; it must use the same
        // (test-isolated) defaults or suites would leak stepTimings across.
        self.messageStore = MessageStore(defaults: userDefaults)
        self.statsStore = SessionStatsStore(defaults: userDefaults)
        self.readStateStore = SessionReadStateStore(defaults: userDefaults)
        self.apiClient = apiClient
        self.sseClient = sseClient
        self.sshTunnelManager = sshTunnelManager ?? SSHTunnelManager()
        self.aiUsageQuotaClient = aiUsageQuotaClient ?? AIUsageQuotaClient()
        self.carSpeechOutput = carSpeechOutput ?? CarSpeechOutputService()
        self.deviceVoice = deviceVoice ?? DeviceVoiceEngine()
        self.deepLinkSessionResolver = deepLinkSessionResolver
        self.deepLinkHydratesSelection = deepLinkHydratesSelection
        self.clientCapabilityStore = clientCapabilityStore
        self.hostCredentialAccess = hostCredentialAccess
        self.clientCapabilityURLOpener = clientCapabilityURLOpener ?? { url in
            #if os(iOS)
            return await UIApplication.shared.open(url)
            #else
            return false
            #endif
        }
        if let storedServer = defaults.string(forKey: Self.serverURLKey) {
            if storedServer == APIConstants.legacyDefaultServer {
                _serverURL = APIClient.defaultServer
                defaults.set(APIClient.defaultServer, forKey: Self.serverURLKey)
            } else {
                _serverURL = storedServer
            }
        } else {
            _serverURL = APIClient.defaultServer
        }
        _username = defaults.string(forKey: Self.usernameKey) ?? ""
        let legacyPasswordLoadFailed: Bool
        do {
            _password = try hostCredentialAccess.load(Self.passwordKeychainKey) ?? ""
            legacyPasswordLoadFailed = false
        } catch {
            _password = ""
            legacyPasswordLoadFailed = true
            hostCredentialError = error.localizedDescription
        }
        loadHostProfilesFromStorageOrLegacy(allowLegacyPersist: !legacyPasswordLoadFailed)
        applyCurrentHostProfileToRuntime(persistLegacy: false)

        _speechRecognitionEngine = SpeechRecognitionEngine.resolved(
            fromRaw: defaults.string(forKey: Self.speechRecognitionEngineKey)
        )
        _selectedProjectWorktree = defaults.string(forKey: Self.selectedProjectWorktreeKey)
        _customProjectPath = defaults.string(forKey: Self.customProjectPathKey) ?? ""
        _languagePreference = L10n.languagePreference
        _aiUsageDashboardURL = defaults.string(forKey: Self.aiUsageDashboardURLKey) ?? ""
        isCarModeEnabled = defaults.bool(forKey: Self.carModeEnabledKey)
        layoutPreference = LayoutPreference.resolved(from: defaults.string(forKey: Self.layoutPreferenceKey))
        voiceFirstInput = defaults.bool(forKey: Self.voiceFirstInputKey)
        composerActionSide = ComposerActionSide.resolved(from: defaults.string(forKey: Self.composerActionSideKey))
        showImageAttachmentButton = defaults.object(forKey: Self.showImageAttachmentButtonKey) as? Bool ?? true
        agentExplicitlyChosen = defaults.bool(forKey: Self.agentExplicitlyChosenKey)
        healthExportPermission = ClientCapabilityPermission(
            rawValue: defaults.string(forKey: Self.healthExportPermissionKey) ?? ""
        ) ?? .ask
        healthExportAllowAlwaysSignature = defaults.string(forKey: Self.healthExportAllowAlwaysSignatureKey)

        loadHostScopedPreferences()

        if let data = defaults.data(forKey: Self.carSessionsByContextKey),
           let decoded = try? JSONDecoder().decode([String: CarSessionRecord].self, from: data) {
            carSessionsByContext = decoded
        }

        if let data = defaults.data(forKey: Self.modelShortlistKey),
           let decoded = try? JSONDecoder().decode([ModelShortlistItem].self, from: data) {
            modelShortlist = decoded
        }

        // The voice engine asks the state to run turns and to speak, so it
        // can only be given its host once the state is fully built.
        self.deviceVoice.host = self
    }

    var sessionScope = SessionScopedState()
    var hostRequestGeneration: UInt64 = 0
    #if os(iOS)
    var watchPhoneBridge: WatchPhoneBridge?
    #endif
    var draftInputsByHost: [String: [String: String]] = [:]
    var selectedModelIDsByHost: [String: [String: String]] = [:]
    var hostProfileBlobUnreadable = false
    var hostProfileLoadError: String?
    var hostCredentialError: String?
    var hostPasswordUnreadable = false
    var hostCredentialAccess = HostCredentialAccess.keychain
    var hostTransportConfigureTask: Task<Void, Never>?

    var draftInputsBySessionID: [String: String] {
        get { draftInputsByHost[currentHostProfileID.uuidString] ?? [:] }
        set { draftInputsByHost[currentHostProfileID.uuidString] = newValue.isEmpty ? nil : newValue }
    }

    var selectedModelIDBySessionID: [String: String] {
        get { selectedModelIDsByHost[currentHostProfileID.uuidString] ?? [:] }
        set { selectedModelIDsByHost[currentHostProfileID.uuidString] = newValue.isEmpty ? nil : newValue }
    }

    var hostProfiles: [HostProfile] = [] {
        didSet { saveHostProfiles() }
    }

    var currentHostProfileID: UUID = UUID() {
        didSet {
            guard !hostProfileBlobUnreadable else { return }
            defaults.set(currentHostProfileID.uuidString, forKey: Self.currentHostProfileIDKey)
        }
    }

    var currentHostProfile: HostProfile? {
        hostProfiles.first { $0.id == currentHostProfileID }
    }

    var _speechRecognitionEngine: SpeechRecognitionEngine = .appleOnDevice
    /// The on-device recognizer used by the `.appleOnDevice` engine.
    /// Injectable so tests can stub authorization and recognition.
    var appleSpeechTranscriber = AppleSpeechTranscriber()
    var speechRecognitionEngine: SpeechRecognitionEngine {
        get { _speechRecognitionEngine }
        set {
            _speechRecognitionEngine = newValue
            defaults.set(newValue.rawValue, forKey: Self.speechRecognitionEngineKey)
        }
    }
    /// Voice input is always ready: the on-device recognizer needs no
    /// account, no token and no network.
    var isChatSpeechConfigured: Bool { true }
    var _aiUsageDashboardURL: String = ""
    var aiUsageDashboardURL: String {
        get { _aiUsageDashboardURL }
        set {
            _aiUsageDashboardURL = newValue
            defaults.set(newValue, forKey: Self.aiUsageDashboardURLKey)
            aiUsageQuotaState = .idle
            aiUsageQuotaTestOK = false
            aiUsageQuotaError = nil
        }
    }
    var aiUsageQuotaState: AIUsageQuotaState = .idle
    var isRefreshingAIUsageProviders = false
    var aiUsageQuotaTestOK = false
    var aiUsageQuotaError: String?
    var isCarModeEnabled = false {
        didSet {
            defaults.set(isCarModeEnabled, forKey: Self.carModeEnabledKey)
            guard oldValue, !isCarModeEnabled else { return }
        }
    }
    var layoutPreference: LayoutPreference = .automatic {
        didSet { defaults.set(layoutPreference.rawValue, forKey: Self.layoutPreferenceKey) }
    }
    var voiceFirstInput = false {
        didSet { defaults.set(voiceFirstInput, forKey: Self.voiceFirstInputKey) }
    }
    var composerActionSide: ComposerActionSide = .right {
        didSet { defaults.set(composerActionSide.rawValue, forKey: Self.composerActionSideKey) }
    }
    var showImageAttachmentButton = true {
        didSet { defaults.set(showImageAttachmentButton, forKey: Self.showImageAttachmentButtonKey) }
    }
    var isConnected: Bool = false {
        didSet {
            guard oldValue, !isConnected else { return }
        }
    }
    var serverVersion: String?
    var connectionError: String?
    var connectionDiagnostic: ConnectionDiagnostic?
    var pendingSSHHostKeyMismatch: SSHHostKeyMismatch?
    var sendError: String?
    var pendingDeepLink: OpenCodeDeepLink?
    var deepLinkRouteState: DeepLinkRouteState = .idle
    var deepLinkError: String?
    var deepLinkRouteID = UUID()

    /// How many connection checks are running right now.
    private var connectionCheckDepth = 0

    /// True while a connection check is running.
    ///
    /// The status row follows this, not the refresh that follows the check:
    /// a refresh also reloads sessions, messages, diffs, todos and the file
    /// tree, and on a large project that takes far longer than the health
    /// check. Reporting "Checking…" for the whole refresh left the row
    /// spinning long after the connection was already proven.
    var isConnectionCheckInFlight: Bool { connectionCheckDepth > 0 }

    /// The diagnostic that belongs to the host that is current now. A
    /// diagnostic left behind by another host says nothing about this one,
    /// so it must not drive this host's status.
    var currentHostConnectionDiagnostic: ConnectionDiagnostic? {
        guard let diagnostic = connectionDiagnostic else { return nil }
        return diagnostic.hostProfileID == currentHostProfileID ? diagnostic : nil
    }

    /// The host cannot be reached: the connection failed, or the app was left
    /// disconnected with an error to explain.
    ///
    /// The Settings surface draws the unplugged plug in this state and the
    /// session list says so instead of claiming the account has no sessions.
    var hostIsUnreachable: Bool {
        HostUnreachablePolicy.isUnreachable(
            isChecking: isConnectionCheckInFlight,
            diagnostic: currentHostConnectionDiagnostic,
            connectionError: connectionError,
            isConnected: isConnected
        )
    }

    /// Marks the start of a connection check.
    func beginConnectionCheck() {
        connectionCheckDepth += 1
    }

    /// Marks the end of a connection check. Every exit of a check runs
    /// this, so the flag cannot outlive the work it describes.
    func endConnectionCheck() {
        connectionCheckDepth = max(0, connectionCheckDepth - 1)
    }

    var sessionActivities: [String: SessionActivity] {
        get { sessionScope.activities }
        set { sessionScope.activities = newValue }
    }

    var sessionStatusUpdatedAt: [String: Date] {
        get { sessionScope.statusUpdatedAt }
        set { sessionScope.statusUpdatedAt = newValue }
    }

    var activityTextLastChangeAt: [String: Date] {
        get { sessionScope.activityTextLastChangeAt }
        set { sessionScope.activityTextLastChangeAt = newValue }
    }

    var activityTextPendingTask: [String: Task<Void, Never>] {
        get { sessionScope.activityTextPendingTask }
        set { sessionScope.activityTextPendingTask = newValue }
    }

    var currentSessionActivity: SessionActivity? {
        guard let sid = currentSessionID else { return nil }
        return sessionActivities[sid]
    }

    func activityTextForSession(_ sessionID: String) -> String {
        ActivityTracker.bestSessionActivityText(
            sessionID: sessionID,
            currentSessionID: currentSessionID,
            sessionStatuses: sessionStatuses,
            messages: messages
        )
    }
    
    /// Unified error handling
    var lastAppError: AppError?
    
    func setError(_ error: Error, type: ErrorType = .connection) {
        let appError = AppError.from(error)
        lastAppError = appError
        
        switch type {
        case .connection:
            connectionError = appError.localizedDescription
        case .send:
            sendError = appError.localizedDescription
        }
    }
    
    func clearError() {
        lastAppError = nil
        connectionError = nil
        sendError = nil
    }
    
    enum ErrorType {
        case connection
        case send
    }

    let defaults: UserDefaults
    let sessionStore: SessionStore
    let messageStore: MessageStore
    let fileStore = FileStore()
    let todoStore = TodoStore()
    let statsStore: SessionStatsStore
    let readStateStore: SessionReadStateStore
    var pendingSessionErrorAt: [String: Date] = [:]
    var statusStreamConnected = false
    var statusConfirmedAt: [String: Date] = [:]
    var statusDirectories: [String: String] = [:]
    var statusRevisions: [String: UInt64] = [:]
    var statusRevision: UInt64 = 0
    var statusKnowledgeRevision: UInt64 = 0
    var statusPollID: UUID?
    var statusLastAttemptAt: Date?
    var statusLastAttemptDirectory: String?
    var statusEvaluationDate = Date()
    var permissionRevision: UInt64 = 0
    var questionRevision: UInt64 = 0
    var permissionPollID: UUID?
    var questionPollID: UUID?
    var pendingRequestEpoch: UInt64 = 0
    var abortingSessionIDs: Set<String> = []
    /// Sessions whose stats must be reset from the post-revert window on the
    /// next `loadMessages` (revert truncates history beyond window visibility).
    var revertResetPendingSessionIDs: Set<String> = []

    var sessions: [Session] { get { sessionStore.sessions } set { sessionStore.sessions = newValue } }
    var sortedSessions: [Session] {
        sessions
            .sorted { $0.time.updated > $1.time.updated }
    }
    var sidebarSessions: [Session] {
        sessions
            .filter { $0.parentID == nil }
            .sorted { $0.time.updated > $1.time.updated }
    }
    var sessionTree: [SessionNode] {
        Self.buildSessionTree(from: sessions)
    }
    var currentSessionID: String? {
        get { sessionStore.currentSessionID }
        set {
            if sessionStore.currentSessionID != newValue {
                markCurrentSessionViewed()
            }
            sessionStore.currentSessionID = newValue
        }
    }

    func markCurrentSessionViewed(at date: Date = Date()) {
        guard let id = currentSessionID, sessions.contains(where: { $0.id == id }) else { return }
        readStateStore.markViewed(sessionID: id, at: date)
    }
    var sessionStatuses: [String: SessionStatus] { get { sessionStore.sessionStatuses } set { sessionStore.sessionStatuses = newValue } }

    var messages: [MessageWithParts] { get { messageStore.messages } set { messageStore.messages = newValue } }
    var partsByMessage: [String: [Part]] { get { messageStore.partsByMessage } set { messageStore.partsByMessage = newValue } }
    var stepTimings: [String: MessageStore.StepTiming] { get { messageStore.stepTimings } set { messageStore.stepTimings = newValue } }

    /// The given session plus every descendant subagent session (linked via
    /// `parentID`), cycle-safe, with the requested session first. Subagents
    /// are same-project sessions spawned by the `task` tool; only those
    /// currently in the loaded session list are returned (pagination
    /// boundary — accepted, off-window subagents are always finished).
    func sessionGroup(including sessionID: String) -> [Session] {
        var seen = Set<String>([sessionID])
        var descendants: [Session] = []
        func visit(_ id: String) {
            for child in sessions where child.parentID == id {
                guard seen.insert(child.id).inserted else { continue }
                descendants.append(child)
                visit(child.id)
            }
        }
        visit(sessionID)
        guard let main = sessions.first(where: { $0.id == sessionID }) else {
            return descendants
        }
        return [main] + descendants
    }

    /// Status-line token total: the session's own cumulative usage plus every
    /// descendant subagent session's, so the number reflects what the whole
    /// conversation tree consumed. The session's own part prefers the
    /// server-maintained aggregate (pushed with every `session.updated`) and
    /// falls back to the loaded message window only when it covers the full
    /// history; subagent parts are aggregate-only, since their message
    /// windows are not loaded. The total is reported only when the session's
    /// own part is knowable — the status line never shows a number it cannot
    /// stand behind.
    func sessionTotalTokens(sessionID: String) -> Int? {
        let group = sessionGroup(including: sessionID)
        let main = group.first { $0.id == sessionID }
        var ownTotal: Int?
        if let own = main?.tokens, own.total > 0 {
            ownTotal = own.total
        } else if main != nil, hasMoreHistoryBySessionID[sessionID] == false {
            let windowSum = messages
                .filter { $0.info.isAssistant }
                .reduce(0) { $0 + ($1.info.tokens?.total ?? 0) }
            ownTotal = windowSum > 0 ? windowSum : nil
        }
        guard let base = ownTotal else { return nil }
        var total = base
        for sub in group.dropFirst() {
            if let tokens = sub.tokens, tokens.total > 0 {
                total += tokens.total
            }
        }
        return total
    }

    /// Status-line cache hit rate over the whole conversation tree: cached
    /// input divided by all input, summed across the session and every
    /// descendant subagent (the aggregate keeps `input` non-cached with
    /// `cache.read` alongside, so the two partition the input side). The
    /// session's own part uses the server aggregate, or the loaded message
    /// window when it covers the full history; subagent parts are
    /// aggregate-only. Reported only when the session's own part is
    /// knowable, mirroring `sessionTotalTokens`.
    func sessionCacheHitRate(sessionID: String) -> Double? {
        let group = sessionGroup(including: sessionID)
        let main = group.first { $0.id == sessionID }
        let ownKnown = main?.tokens != nil || hasMoreHistoryBySessionID[sessionID] == false
        guard ownKnown else { return nil }
        var freshInput = 0
        var cacheRead = 0
        for session in group {
            // An input-less aggregate (fresh session) carries no rate
            // information; the main session then falls back to its window.
            if let tokens = session.tokens, tokens.input + (tokens.cache?.read ?? 0) > 0 {
                freshInput += tokens.input
                cacheRead += tokens.cache?.read ?? 0
            } else if session.id == sessionID, hasMoreHistoryBySessionID[sessionID] == false {
                for row in messages where row.info.isAssistant {
                    freshInput += row.info.tokens?.input ?? 0
                    cacheRead += row.info.tokens?.cache?.read ?? 0
                }
            }
        }
        return Self.cacheHitRate(freshInput: freshInput, cacheRead: cacheRead)
    }

    private static func cacheHitRate(freshInput: Int, cacheRead: Int) -> Double? {
        let denominator = freshInput + cacheRead
        guard denominator > 0 else { return nil }
        return Double(cacheRead) / Double(denominator)
    }

    /// Index into `pickerModelPresets`. 0 until the session's own pick (or the
    /// server's default) is resolved — never an arbitrary position, which
    /// used to point at a model the user never selected.
    var selectedModelIndex: Int = 0
    
    var agents: [AgentInfo] = [
        AgentInfo(name: "OpenCode-Builder", description: "Build agent (OpenCode default)", mode: "all", hidden: false, native: false),
        AgentInfo(name: "Sisyphus (Ultraworker)", description: "Powerful AI orchestrator", mode: "primary", hidden: false, native: false),
        AgentInfo(name: "Hephaestus (Deep Agent)", description: "Autonomous Deep Worker", mode: "primary", hidden: false, native: false),
        AgentInfo(name: "Prometheus (Plan Builder)", description: "Plan agent", mode: "all", hidden: false, native: false),
        AgentInfo(name: "Atlas (Plan Executor)", description: "Plan Executor", mode: "primary", hidden: false, native: false),
    ]
    var selectedAgentIndex: Int = 0
    /// Name actually sent to the server. Not an index into a previous host's list.
    var selectedAgentName: String = AgentInfo.fallbackAgentName
    /// True once the user picked an agent from the server catalog. Until
    /// then the app sends no agent at all and the server uses its own default
    /// — a stale or unvalidated name fails every prompt server-side.
    var agentExplicitlyChosen = false {
        didSet {
            defaults.set(agentExplicitlyChosen, forKey: Self.agentExplicitlyChosenKey)
        }
    }
    /// True only after GET /agent succeeds for the current host.
    var hasServerAgentCatalog: Bool = false
    var isLoadingAgents: Bool = false

    var expandedSessionIDs: Set<String> = []

    func filteredSessions(archived: Bool) -> [Session] {
        return sessions
            .filter { $0.isArchived == archived }
            .sorted { $0.time.updated > $1.time.updated }
    }

    func sessionTree(archived: Bool, query: String = "") -> [SessionNode] {
        let tree = Self.prioritizeAttention(
            Self.buildSessionTree(from: filteredSessions(archived: archived)),
            attentionCounts: sessionAttentionCounts,
            descendantBusyCounts: sessionDescendantBusyCounts
        )
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tree }
        func matching(_ nodes: [SessionNode]) -> [SessionNode] {
            nodes.compactMap { node in
                let children = matching(node.children)
                guard node.session.title.localizedCaseInsensitiveContains(query) || !children.isEmpty else { return nil }
                return SessionNode(session: node.session, children: children)
            }
        }
        return matching(tree)
    }

    var attentionSessionIDs: [String] {
        pendingPermissions.map(\.sessionID) + pendingQuestions.map(\.sessionID)
    }

    var sessionAttentionCounts: [String: Int] {
        Self.attentionCountsBySession(
            sessions: sessions,
            attentionSessionIDs: attentionSessionIDs
        )
    }

    /// Number of running descendant subagent sessions per session, derived from
    /// the global `sessionStatuses` map along `parentID` links. A session's own
    /// busy state is never counted, so a row can render a distinct "subagents
    /// running" signal side by side with (and subordinate to) its own Running.
    var sessionDescendantBusyCounts: [String: Int] {
        Self.descendantBusyCountsBySession(
            sessions: sessions,
            sessionStatuses: sessionStatuses
        )
    }

    /// Busy descendant subagent sessions of `sessionID`, most recently updated
    /// first. Drives the composer "background tasks running" segment; BFS over
    /// `parentID` links is cycle-safe and covers arbitrary nesting.
    func runningDescendantSessions(of sessionID: String) -> [Session] {
        let childrenByParent = Dictionary(grouping: sessions, by: \.parentID)
        var running: [Session] = []
        var visited = Set<String>([sessionID])
        var queue = [sessionID]
        while let current = queue.first {
            queue.removeFirst()
            for child in childrenByParent[current] ?? [] {
                guard visited.insert(child.id).inserted else { continue }
                if isBusySession(sessionStatuses[child.id]) {
                    running.append(child)
                }
                queue.append(child.id)
            }
        }
        return running.sorted { $0.time.updated > $1.time.updated }
    }

    var projects: [Project] = []
    var isLoadingProjects: Bool = false
    /// Server's current project worktree (from GET /project/current). Used to detect mismatch with user selection.
    var serverCurrentProjectWorktree: String? {
        get { _serverCurrentProjectWorktree }
        set { noteServerCurrentProjectWorktree(newValue) }
    }
    var _serverCurrentProjectWorktree: String?

    /// When user selected a project but server's default differs: new sessions will be created in server's project.
    /// User should switch project in Web client first.
    var projectMismatchWarning: String? {
        guard let effective = effectiveProjectDirectory, !effective.isEmpty else { return nil }
        guard let server = serverCurrentProjectWorktree else { return nil }
        guard effective != server else { return nil }
        let effectiveName = (effective as NSString).lastPathComponent
        let serverName = (server as NSString).lastPathComponent
        return L10n.t(.settingsProjectMismatchWarning).replacingOccurrences(of: "{effective}", with: effectiveName).replacingOccurrences(of: "{server}", with: serverName)
    }

    /// Only allow creating sessions when using server default project. When a specific project is selected,
    /// new sessions would go to server default (API limitation), so we disable create and show hint.
    var canCreateSession: Bool {
        effectiveProjectDirectory == nil
    }

    /// Hint shown when create is disabled (user selected a project ≠ server default).
    var createSessionDisabledHint: String {
        L10n.t(.chatCreateDisabledHint)
    }

    var selectedProjectWorktree: String? {
        get { _selectedProjectWorktree }
        set {
            let previous = carContextKey
            _selectedProjectWorktree = newValue
            defaults.set(newValue, forKey: Self.selectedProjectWorktreeKey)
            if carContextKey != previous {
                #if os(iOS)
                watchPhoneBridge?.invalidate()
                #endif
                invalidateCarTurnForRealProjectChange()
            }
        }
    }
    var _selectedProjectWorktree: String?

    var customProjectPath: String {
        get { _customProjectPath }
        set {
            let previous = carContextKey
            _customProjectPath = newValue
            defaults.set(newValue, forKey: Self.customProjectPathKey)
            if carContextKey != previous {
                #if os(iOS)
                watchPhoneBridge?.invalidate()
                #endif
                invalidateCarTurnForRealProjectChange()
            }
        }
    }
    var _customProjectPath: String = ""

    /// Effective directory for session fetch: selected project or custom path, nil = server default
    var effectiveProjectDirectory: String? {
        guard let sel = selectedProjectWorktree, !sel.isEmpty else { return nil }
        if sel == Self.customProjectSentinel {
            let path = customProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? nil : path
        }
        return sel
    }
    /// Sentinel value when user selects "Custom path" option
    static let customProjectSentinel = "__custom__"

    var pendingPermissions: [PendingPermission] {
        get { sessionScope.pendingPermissions }
        set { sessionScope.pendingPermissions = newValue }
    }

    var pendingQuestions: [QuestionRequest] {
        get { sessionScope.pendingQuestions }
        set { sessionScope.pendingQuestions = newValue }
    }

    var themePreference: String = "auto"  // "auto" | "light" | "dark"
    var _languagePreference: L10n.LanguagePreference = .system
    var languagePreference: L10n.LanguagePreference {
        get { _languagePreference }
        set {
            _languagePreference = newValue
            L10n.languagePreference = newValue
        }
    }

    /// Write the pending session statistics out now.
    func flushSessionStats() {
        statsStore.flush()
    }

    var sessionDiffs: [FileDiff] { get { fileStore.sessionDiffs } set { fileStore.sessionDiffs = newValue } }
    var selectedDiffFile: String? { get { fileStore.selectedDiffFile } set { fileStore.selectedDiffFile = newValue } }
    var selectedTab: Int = RootTab.chat.rawValue
    /// When set, Settings should open and pulse the matching row.
    var settingsFocus: SettingsFocus?
    var fileToOpenInFilesTab: String?  // 从 Chat 中 tool 点击跳转时设置，Files tab 或 sheet 展示
    var fileToOpenInFilesTabWorkspaceDirectory: String?

    /// iPad 三栏布局：中间栏文件预览
    var previewFilePath: String?
    var previewFileWorkspaceDirectory: String?
    var inlinePreviewPath: String?
    var inlinePreviewWorkspaceDirectory: String?
    /// Compact Files tab push. Not session-scoped.
    var filesNavigationPath: [String] = []
    var filesNavigationWorkspace: String?
    var filesNavigationHostID: UUID?
    var ignoreNextFilesPathShrink = false
    /// Set for chat-opened previews. Nil means the preview is not tied to a session.
    var previewSessionID: String?
    var previewHostID: UUID?
    var previewEventSequence: UInt64 = 0
    var columnEventSequence: UInt64 = 0
    var inlineEventSequence: UInt64 = 0
    var pendingEventSequence: UInt64 = 0
    var pendingFileOpenOwner: ExternalFileOpenOwner?
    var filesEventSequence: UInt64 = 0

    func closeFilePreview() {
        previewFilePath = nil
        previewFileWorkspaceDirectory = nil
        inlinePreviewPath = nil
        inlinePreviewWorkspaceDirectory = nil
        fileToOpenInFilesTab = nil
        fileToOpenInFilesTabWorkspaceDirectory = nil
        pendingFileOpenOwner = nil
        clearFilesNavigationPathIgnoringNextShrink()
        filesNavigationWorkspace = nil
        filesNavigationHostID = nil
        previewSessionID = nil
        previewHostID = nil
        columnEventSequence = 0
        inlineEventSequence = 0
        pendingEventSequence = 0
        filesEventSequence = 0
    }

    func externalFileOpenOwnerIsCurrent(_ owner: ExternalFileOpenOwner) -> Bool {
        guard isCurrentHostRequest(owner.host) else { return false }
        if let sessionID = owner.sessionID {
            return sessionID == currentSessionID
        }
        return true
    }

    func stageExternalFileOpen(path: String, workspaceDirectory: String?, owner: ExternalFileOpenOwner) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard externalFileOpenOwnerIsCurrent(owner) else { return }
        previewEventSequence &+= 1
        pendingEventSequence = previewEventSequence
        fileToOpenInFilesTab = trimmed
        fileToOpenInFilesTabWorkspaceDirectory = PreviewWorkspacePin.freeze(
            explicit: workspaceDirectory,
            sessionDirectory: currentSession?.directory
        )
        pendingFileOpenOwner = owner
    }

    func clearFilesNavigationPathIgnoringNextShrink() {
        guard !filesNavigationPath.isEmpty else { return }
        ignoreNextFilesPathShrink = true
        filesNavigationPath = []
        filesNavigationWorkspace = nil
    }

    func adoptFilesPush(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let workspace = effectiveProjectDirectory ?? ""
        previewEventSequence &+= 1
        columnEventSequence = previewEventSequence
        filesEventSequence = previewEventSequence
        inlineEventSequence = 0
        pendingEventSequence = 0
        previewFilePath = trimmed
        previewFileWorkspaceDirectory = workspace
        inlinePreviewPath = nil
        inlinePreviewWorkspaceDirectory = nil
        fileToOpenInFilesTab = nil
        fileToOpenInFilesTabWorkspaceDirectory = nil
        pendingFileOpenOwner = nil
        filesNavigationWorkspace = workspace
        filesNavigationHostID = currentHostProfileID
        previewHostID = currentHostProfileID
        previewSessionID = nil
    }

    func presentChatFilePreview(path: String, workspaceDirectory: String?, layout: EffectiveLayout) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let workspace = PreviewWorkspacePin.freeze(
            explicit: workspaceDirectory,
            sessionDirectory: currentSession?.directory
        )
        clearFilesNavigationPathIgnoringNextShrink()
        fileToOpenInFilesTab = nil
        fileToOpenInFilesTabWorkspaceDirectory = nil
        pendingFileOpenOwner = nil
        previewEventSequence &+= 1
        previewHostID = currentHostProfileID
        previewSessionID = currentSessionID
        pendingEventSequence = 0
        if layout == .regular {
            columnEventSequence = previewEventSequence
            inlineEventSequence = 0
            previewFilePath = trimmed
            previewFileWorkspaceDirectory = workspace
            inlinePreviewPath = nil
            inlinePreviewWorkspaceDirectory = nil
        } else {
            inlineEventSequence = previewEventSequence
            columnEventSequence = 0
            inlinePreviewPath = trimmed
            inlinePreviewWorkspaceDirectory = workspace
            previewFilePath = nil
            previewFileWorkspaceDirectory = nil
        }
    }

    func presentFilesColumnPreview(path: String, workspaceDirectory: String?) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let workspace = workspaceDirectory ?? ""
        previewEventSequence &+= 1
        columnEventSequence = previewEventSequence
        inlineEventSequence = 0
        pendingEventSequence = 0
        previewFilePath = trimmed
        previewFileWorkspaceDirectory = workspace
        inlinePreviewPath = nil
        inlinePreviewWorkspaceDirectory = nil
        previewHostID = currentHostProfileID
        previewSessionID = nil
        filesNavigationHostID = currentHostProfileID
        clearFilesNavigationPathIgnoringNextShrink()
        fileToOpenInFilesTab = nil
        fileToOpenInFilesTabWorkspaceDirectory = nil
        pendingFileOpenOwner = nil
    }

    func closeMatchingPreview(_ path: String?) {
        guard let path, !path.isEmpty else { return }
        guard previewFilePath == path || inlinePreviewPath == path || filesNavigationPath.last == path else { return }
        closeFilePreview()
    }

    func discardPreviewIfHostChanged(from oldHost: UUID, to newHost: UUID) {
        guard oldHost != newHost else { return }
        if previewHostID != newHost {
            previewFilePath = nil
            previewFileWorkspaceDirectory = nil
            inlinePreviewPath = nil
            inlinePreviewWorkspaceDirectory = nil
            previewSessionID = nil
            previewHostID = nil
            fileToOpenInFilesTab = nil
            fileToOpenInFilesTabWorkspaceDirectory = nil
            pendingFileOpenOwner = nil
        }
        if filesNavigationHostID != newHost {
            clearFilesNavigationPathIgnoringNextShrink()
            filesNavigationWorkspace = nil
            filesNavigationHostID = nil
            filesEventSequence = 0
        }
    }

    func discardChatPreviewIfSessionChanged(from oldSession: String?, to newSession: String?) {
        guard oldSession != newSession, let boundSession = previewSessionID, boundSession == oldSession else { return }
        inlinePreviewPath = nil
        inlinePreviewWorkspaceDirectory = nil
        let columnPath = previewFilePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if columnPath.isEmpty {
            previewFilePath = nil
            previewFileWorkspaceDirectory = nil
        }
        previewSessionID = nil
    }

    func applyPreviewLayout(from: EffectiveLayout, to: EffectiveLayout) {
        let output = PreviewLayoutTransition.apply(
            from: from,
            to: to,
            input: PreviewLayoutInput(
                slots: LayoutPreviewSlots(
                    inlinePath: inlinePreviewPath,
                    inlineWorkspace: inlinePreviewWorkspaceDirectory,
                    columnPath: previewFilePath,
                    columnWorkspace: previewFileWorkspaceDirectory
                ),
                columnSequence: columnEventSequence,
                inlineSequence: inlineEventSequence,
                filesPath: filesNavigationPath,
                filesWorkspace: filesNavigationWorkspace ?? effectiveProjectDirectory,
                filesHostMatches: filesNavigationHostID == nil || filesNavigationHostID == currentHostProfileID,
                filesSequence: filesEventSequence,
                pendingPath: fileToOpenInFilesTab,
                pendingWorkspace: fileToOpenInFilesTabWorkspaceDirectory,
                pendingHostMatches: pendingFileOpenOwner.map(externalFileOpenOwnerIsCurrent) == true,
                pendingSequence: pendingEventSequence
            )
        )
        pendingFileOpenOwner = nil
        inlinePreviewPath = output.slots.inlinePath
        inlinePreviewWorkspaceDirectory = output.slots.inlineWorkspace
        previewFilePath = output.slots.columnPath
        previewFileWorkspaceDirectory = output.slots.columnWorkspace
        if output.slots.inlinePath != nil, previewSessionID == nil {
            previewSessionID = currentSessionID
        }
        if output.slots.inlinePath != nil {
            inlineEventSequence = output.winnerSequence
            columnEventSequence = 0
        } else if output.slots.columnPath != nil {
            columnEventSequence = output.winnerSequence
            inlineEventSequence = 0
        } else {
            inlineEventSequence = 0
            columnEventSequence = 0
        }
        pendingEventSequence = 0
        fileToOpenInFilesTab = output.pendingPath
        fileToOpenInFilesTabWorkspaceDirectory = output.pendingWorkspace
        if output.filesPath != filesNavigationPath {
            ignoreNextFilesPathShrink = true
            filesNavigationPath = output.filesPath
        }
        if output.filesPath.isEmpty {
            filesNavigationWorkspace = nil
        }
    }

    func adoptPendingFileOpen(layout: EffectiveLayout) {
        guard let path = fileToOpenInFilesTab, !path.isEmpty else { return }
        guard let owner = pendingFileOpenOwner, externalFileOpenOwnerIsCurrent(owner) else {
            fileToOpenInFilesTab = nil
            fileToOpenInFilesTabWorkspaceDirectory = nil
            pendingFileOpenOwner = nil
            return
        }
        let visibleSequence = layout == .regular ? columnEventSequence : inlineEventSequence
        let visiblePath = layout == .regular ? previewFilePath : inlinePreviewPath
        if let visiblePath, !visiblePath.isEmpty, pendingEventSequence <= visibleSequence {
            fileToOpenInFilesTab = nil
            fileToOpenInFilesTabWorkspaceDirectory = nil
            pendingFileOpenOwner = nil
            return
        }
        let workspace = PreviewWorkspacePin.freeze(
            explicit: fileToOpenInFilesTabWorkspaceDirectory,
            sessionDirectory: currentSession?.directory
        )
        previewHostID = owner.host.hostProfileID
        previewSessionID = owner.sessionID
        clearFilesNavigationPathIgnoringNextShrink()
        filesEventSequence = 0
        if layout == .regular {
            columnEventSequence = pendingEventSequence
            inlineEventSequence = 0
            previewFilePath = path
            previewFileWorkspaceDirectory = workspace
            inlinePreviewPath = nil
            inlinePreviewWorkspaceDirectory = nil
        } else {
            inlineEventSequence = pendingEventSequence
            columnEventSequence = 0
            inlinePreviewPath = path
            inlinePreviewWorkspaceDirectory = workspace
            previewFilePath = nil
            previewFileWorkspaceDirectory = nil
        }
        pendingEventSequence = 0
        fileToOpenInFilesTab = nil
        fileToOpenInFilesTabWorkspaceDirectory = nil
        pendingFileOpenOwner = nil
    }

    var sessionTodos: [String: [TodoItem]] { get { todoStore.sessionTodos } set { todoStore.sessionTodos = newValue } }

    var fileTreeRoot: [FileNode] { get { fileStore.fileTreeRoot } set { fileStore.fileTreeRoot = newValue } }
    var fileStatusMap: [String: String] { get { fileStore.fileStatusMap } set { fileStore.fileStatusMap = newValue } }
    var expandedPaths: Set<String> { get { fileStore.expandedPaths } set { fileStore.expandedPaths = newValue } }
    var fileChildrenCache: [String: [FileNode]] { get { fileStore.fileChildrenCache } set { fileStore.fileChildrenCache = newValue } }
    var fileSearchQuery: String { get { fileStore.fileSearchQuery } set { fileStore.fileSearchQuery = newValue } }
    var fileSearchResults: [String] { get { fileStore.fileSearchResults } set { fileStore.fileSearchResults = newValue } }

    // Provider config cache (for context usage ring + dynamic model picker)
    var providersResponse: ProvidersResponse? = nil
    var providerModelsIndex: [String: ProviderModel] = [:]
    var providerConfigError: String? = nil
    /// Full chat-capable catalog from connected providers. Settings search
    /// uses this; the chat picker does not.
    var catalogModelPresets: [ModelPreset] = []
    /// Device-local picker membership. Persisted separately from the desktop
    /// manage-models store, which the server API does not expose.
    var modelShortlist: [ModelShortlistItem] = [] {
        didSet {
            persistModelShortlist()
            rebuildPickerModelItems(reason: "shortlist")
        }
    }
    /// Catalog alias for existing tests and diagnostics.
    var dynamicModelPresets: [ModelPreset] { catalogModelPresets }
    /// Provider display names for grouping the dynamic picker
    /// (providerID -> human name, e.g. "ollama" -> "Ollama (local)").
    var providerDisplayNames: [String: String] = [:]
    /// Model picker search text. Lives in AppState (not view @State) because
    /// the iOS 26 sheet content closure does not track the presenting view's
    /// @State updates — device log pdiag3: cached=18 groups but the sheet's
    /// List evaluated modelGroups as empty and dropped the agent section.
    var modelSearchText: String = ""
    /// Flat picker rows (provider header rows + model rows) rendered as one
    /// Section. Flat because iOS 26 List mis-diffs ForEach-generated dynamic
    /// Sections (pdiag1: false duplicate-ID warnings; pdiag2/3: zero rendered).
    var pickerModelItems: [ModelPickerItem] = []
    var pickerModelGen = 0

    let apiClient: APIClientProtocol
    let sseClient: SSEClientProtocol
    let sshTunnelManager: SSHTunnelManager
    let aiUsageQuotaClient: AIUsageQuotaClientProtocol
    let deepLinkSessionResolver: ((String) async throws -> Session)?
    let deepLinkHydratesSelection: Bool
    var sseTask: Task<Void, Never>?
    /// Time the last SSE frame of any type (including heartbeats) was
    /// received. Internal so unit tests can pre-seed it and drive
    /// `checkSSEWatchdog()` deterministically.
    var sseLastFrameAt: Date?
    /// Heartbeat watchdog for the current `sseConnectionToken` only.
    var sseWatchdogTask: Task<Void, Never>?
    var sseConnectionToken: UInt64 = 0
    var sseReconnectSleep: (TimeInterval) async -> Void = { seconds in
        try? await Task.sleep(for: .seconds(seconds))
    }
    nonisolated static let sseWatchdogCheckInterval: TimeInterval = 5
    nonisolated static let sseSilenceThreshold: TimeInterval = 20

    var carSessionsByContext: [String: CarSessionRecord] = [:]

    /// True while the chat composer holds the device microphone open.
    ///
    /// Published by the composer at the moment it starts and stops the capture,
    /// so it is true for the whole window the engine is live — not only while
    /// `isRecording` is set, which is set later and cleared earlier.
    var chatSpeechCaptureActive = false

    /// True while any device microphone may be open.
    ///
    /// This is the single authoritative answer for "may I announce something
    /// audibly or haptically right now". It covers the Ambient/Car live-voice
    /// capture and the chat composer capture.
    ///
    /// The Ambient path matters: it answers permissions *by voice*, so a
    /// `permission.asked` event is a designed step of that flow and is expected
    /// to arrive while the microphone is open.
    var isMicrophoneCaptureActive: Bool {
        chatSpeechCaptureActive || deviceVoice.isListening
    }

    /// Permission and question requests that have already been announced
    /// haptically. See `DesignAnnouncementLedger` for why this is not derived
    /// from the live pending lists.
    var announcedPermissions = DesignAnnouncementLedger()
    var announcedQuestions = DesignAnnouncementLedger()

    /// Announce a permission request, unless this exact request was already
    /// announced. Returns whether the announcement happened.
    @discardableResult
    func announcePermissionArrival(_ id: String) -> Bool {
        guard announcedPermissions.needsAnnouncement(id) else { return false }
        announcedPermissions.markAnnounced(id)
        DesignHaptics.fire(.permissionArrived, microphoneOpen: isMicrophoneCaptureActive)
        return true
    }

    /// Announce a question request, unless this exact request was already
    /// announced. Returns whether the announcement happened.
    @discardableResult
    func announceQuestionArrival(_ id: String) -> Bool {
        guard announcedQuestions.needsAnnouncement(id) else { return false }
        announcedQuestions.markAnnounced(id)
        DesignHaptics.fire(.questionArrived, microphoneOpen: isMicrophoneCaptureActive)
        return true
    }
    var backgroundVoiceScene: BackgroundVoiceSceneKind = .active
    var backgroundVoiceEpoch: UInt64 = 0
    var holdingBackgroundVoice = false
    var skipForegroundConnectionRestore = false
    var foregroundHoldRestoreConsumed = false
    var backgroundCleanupApplied = false
    var applyingBackgroundCleanup = false
    var carPhase: CarModePhase = .idle
    var carLastTranscript = ""
    var carLastResponse: CarResponseEnvelope?
    var carError: String?
    var carActiveTurnID: UUID?
    var carActiveCapabilityCallbackID: String?
    var carLastKnownServerWorktree: String?
    let carSpeechOutput: CarSpeechOutputProviding

    /// The hands-free voice loop: on-device recognition, the user's own server
    /// as the brain, on-device speech.
    let deviceVoice: DeviceVoiceEngine
    let clientCapabilityStore: ClientCapabilityCallbackStore
    let clientCapabilityURLOpener: @MainActor (URL) async -> Bool
    var pendingClientCapabilityRequest: PendingClientCapabilityRequest?
    var clientCapabilityError: String?
    var clientCapabilityInFlightCallbackIDs: Set<String> = []
    var healthExportPermission: ClientCapabilityPermission = .ask {
        didSet {
            if healthExportPermission == .ask {
                defaults.removeObject(forKey: Self.healthExportPermissionKey)
                defaults.removeObject(forKey: Self.healthExportAllowAlwaysSignatureKey)
            } else {
                defaults.set(healthExportPermission.rawValue, forKey: Self.healthExportPermissionKey)
            }
        }
    }
    /// The host signature stored alongside an "Always Allow" grant.
    var healthExportAllowAlwaysSignature: String?

    /// Whether the stored automatic grant applies to the *current* host. The
    /// grant is host-scoped: a different host — or the same host after its
    /// address/credentials changed — prompts again instead of silently
    /// auto-allowing.
    var healthExportAutoAllowIsActive: Bool {
        guard healthExportPermission == .allowAlways,
              let signature = healthExportAllowAlwaysSignature, !signature.isEmpty,
              let currentSignature = clientCapabilityHostSignature(for: currentHostProfileID) else {
            return false
        }
        return signature == currentSignature
    }

    func grantHealthExportAlwaysAllow() {
        healthExportPermission = .allowAlways
        healthExportAllowAlwaysSignature = clientCapabilityHostSignature(for: currentHostProfileID)
        if let signature = healthExportAllowAlwaysSignature {
            defaults.set(signature, forKey: Self.healthExportAllowAlwaysSignatureKey)
        } else {
            // No resolvable host: a hostless grant would silently apply to
            // whoever connects next, so don't persist one.
            healthExportPermission = .ask
        }
    }

    /// Guard against race conditions when rapidly switching sessions.
    /// Each selectSession call generates a new ID; async tasks check if they're still current.
    var sessionLoadingID = UUID()
    var messageSnapshotRequestSequence: UInt64 = 0
    var acceptedMessageSnapshotSequence: UInt64 = 0
    nonisolated private static let sessionPageSize = 400
    var loadedSessionLimit = sessionPageSize
    var hasMoreSessions = true
    var isLoadingMoreSessions = false

    var canLoadMoreSessions: Bool {
        hasMoreSessions && !isLoadingMoreSessions
    }

    func resetSessionPagination() {
        isLoadingMoreSessions = false
        loadedSessionLimit = Self.sessionPageSize
        hasMoreSessions = true
    }

    // WAN optimization: page message history in fixed-size message batches.
    nonisolated private static let messagePageSize = 20
    var loadedMessageLimitBySessionID: [String: Int] {
        get { sessionScope.loadedMessageLimit }
        set { sessionScope.loadedMessageLimit = newValue }
    }

    var hasMoreHistoryBySessionID: [String: Bool] {
        get { sessionScope.hasMoreHistory }
        set { sessionScope.hasMoreHistory = newValue }
    }

    var loadingOlderMessagesSessionIDs: Set<String> {
        get { sessionScope.loadingOlderMessages }
        set { sessionScope.loadingOlderMessages = newValue }
    }

    var selectedModel: ModelPreset? {
        pickerModelPresets.indices.contains(selectedModelIndex) ? pickerModelPresets[selectedModelIndex] : nil
    }

    /// The model the session will actually run on: the user's explicit pick
    /// for it, otherwise the server's own default.
    ///
    /// This is the only model the app is allowed to write to the server
    /// session. The picker's *index* is a UI position, not a decision: with a
    /// default of 2 it pointed at whatever third entry the shortlist had —
    /// including a provider the user never chose — and because the model
    /// lives on the shared session, every other client inherited it.
    var effectiveModelPreset: ModelPreset? {
        if let picked = sessionModelPreset { return picked }
        guard let model = providersResponse?.default else { return nil }
        return ModelPreset(
            displayName: model.modelID,
            providerID: model.providerID,
            modelID: model.modelID
        )
    }

    /// The model the user explicitly chose for the current session, if any.
    ///
    /// This is the only model the app is allowed to write to the server
    /// session. The picker's *index* is a UI position, not a decision: with a
    /// default of 2 it pointed at whatever third entry the shortlist had —
    /// including a provider the user never chose — and because the model
    /// lives on the shared session, every other client inherited it.
    var sessionModelPreset: ModelPreset? {
        guard let sessionID = currentSessionID,
              let savedID = selectedModelIDBySessionID[sessionID],
              let preset = pickerModelPresets.first(where: { $0.id == savedID }) else {
            return nil
        }
        return preset
    }

    /// Chat picker source: only the local shortlist.
    var pickerModelPresets: [ModelPreset] {
        modelShortlist.map { $0.asPreset() }
    }
    
    var selectedAgent: AgentInfo? {
        let visibleAgents = agents.filter { $0.isVisible }
        guard visibleAgents.indices.contains(selectedAgentIndex) else { return nil }
        return visibleAgents[selectedAgentIndex]
    }
    
    var visibleAgents: [AgentInfo] {
        agents.filter { $0.isVisible }
    }

    var isCurrentSessionHistoryTruncated: Bool {
        guard let sessionID = currentSessionID else { return false }
        return hasMoreHistoryBySessionID[sessionID] ?? false
    }

    var isLoadingOlderMessagesInCurrentSession: Bool {
        guard let sessionID = currentSessionID else { return false }
        return loadingOlderMessagesSessionIDs.contains(sessionID)
    }

    nonisolated static func normalizedMessageFetchLimit(
        current: Int?,
        pageSize: Int = 20
    ) -> Int {
        let fallback = max(pageSize, 1)
        guard let current else { return fallback }
        return max(current, fallback)
    }

    nonisolated static func nextMessageFetchLimit(
        current: Int?,
        pageSize: Int = 20
    ) -> Int {
        normalizedMessageFetchLimit(current: current, pageSize: pageSize) + max(pageSize, 1)
    }

    nonisolated static func nextSessionIDAfterDeleting(
        deletedSessionID: String,
        currentSessionID: String?,
        remainingSessions: [Session]
    ) -> String? {
        guard currentSessionID == deletedSessionID else { return currentSessionID }
        return remainingSessions
            .sorted { $0.time.updated > $1.time.updated }
            .first?
            .id
    }

    nonisolated static func nextSessionFetchLimit(
        current: Int,
        pageSize: Int = sessionPageSize
    ) -> Int {
        max(current, pageSize) + max(pageSize, 1)
    }

    nonisolated static func buildSessionTree(from sessions: [Session]) -> [SessionNode] {
        let sessionIDs = Set(sessions.map(\.id))
        let childrenMap = Dictionary(grouping: sessions, by: \.parentID)

        func buildNodes(parentID: String?) -> [SessionNode] {
            (childrenMap[parentID] ?? [])
                .sorted { $0.time.updated > $1.time.updated }
                .map { session in
                    SessionNode(session: session, children: buildNodes(parentID: session.id))
                }
        }

        var roots = buildNodes(parentID: nil)

        let orphans = sessions
            .filter { session in
                guard let pid = session.parentID else { return false }
                return !sessionIDs.contains(pid)
            }
            .sorted { $0.time.updated > $1.time.updated }
            .map { session in
                SessionNode(session: session, children: buildNodes(parentID: session.id))
            }

        roots.append(contentsOf: orphans)
        roots.sort { $0.session.time.updated > $1.session.time.updated }
        return roots
    }

    nonisolated static func settled(_ status: SessionStatus?) -> Bool {
        status?.type == "idle"
    }

    nonisolated static func unreadSessionIDs(
        sessions: [Session],
        statuses: [String: SessionStatus],
        lastViewedAt: [String: Date]
    ) -> [String] {
        sessions.filter {
            // This is only a content candidate. Missing execution knowledge
            // remains unknown and cannot produce blue in the presentation.
            (statuses[$0.id]?.type == nil || settled(statuses[$0.id]))
                && Date(timeIntervalSince1970: Double($0.time.updated) / 1000)
                    > (lastViewedAt[$0.id] ?? .distantPast)
        }.map(\.id)
    }

    nonisolated static func unreadCountsBySession(
        sessions: [Session],
        unreadIDs: [String],
        lastViewedAt: [String: Date] = [:]
    ) -> [String: Int] {
        blueReminderSourcesBySession(sessions: sessions, unreadIDs: unreadIDs,
                                     lastViewedAt: lastViewedAt).mapValues(\.count)
    }

    nonisolated static func blueReminderSourcesBySession(
        sessions: [Session],
        unreadIDs: [String],
        lastViewedAt: [String: Date],
        acknowledgements: [String: [String: Int]] = [:]
    ) -> [String: [String: Int]] {
        let sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        var sources: [String: [String: Int]] = [:]
        for sourceID in unreadIDs {
            guard let source = sessionsByID[sourceID] else { continue }
            let updated = Date(timeIntervalSince1970: Double(source.time.updated) / 1000)
            guard updated > (lastViewedAt[sourceID] ?? .distantPast) else { continue }
            var sessionID: String? = sourceID
            var visited: Set<String> = []
            while let id = sessionID, visited.insert(id).inserted {
                // A row confirms only its own reminder; never stop propagation to higher rows.
                if id == sourceID || source.time.updated <= 0
                    || acknowledgements[id]?[sourceID] != source.time.updated {
                    sources[id, default: [:]][sourceID] = source.time.updated
                }
                sessionID = sessionsByID[id]?.parentID
            }
        }
        return sources
    }

    var sessionBlueReminderSources: [String: [String: Int]] {
        let viewed = Dictionary(uniqueKeysWithValues: sessions.compactMap { session in
            readStateStore.lastViewedAt(for: session.id).map { (session.id, $0) }
        })
        let acknowledgements = Dictionary(uniqueKeysWithValues: sessions.map {
            ($0.id, readStateStore.blueAcknowledgements(for: $0.id))
        })
        let settledIDs = Self.unreadSessionIDs(sessions: sessions, statuses: sessionStatuses, lastViewedAt: [:])
        return Self.blueReminderSourcesBySession(sessions: sessions, unreadIDs: settledIDs,
                                                lastViewedAt: viewed, acknowledgements: acknowledgements)
    }

    /// Row reminders, not a count of all unread content in the subtree.
    var sessionUnreadCounts: [String: Int] {
        sessionBlueReminderSources.mapValues(\.count)
    }

    nonisolated static func failureCountsBySession(
        sessions: [Session],
        failedAt: [String: Date],
        lastViewedAt: [String: Date]
    ) -> [String: Int] {
        let sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        var counts: [String: Int] = [:]
        for (sourceID, failed) in failedAt {
            var sessionID: String? = sourceID
            var visited: Set<String> = []
            while let id = sessionID, visited.insert(id).inserted {
                if failed > (lastViewedAt[sourceID] ?? .distantPast) {
                    counts[id, default: 0] += 1
                }
                sessionID = sessionsByID[id]?.parentID
            }
        }
        return counts
    }

    var sessionFailureCounts: [String: Int] {
        let failed = Dictionary(uniqueKeysWithValues: sessions.compactMap { session in
            readStateStore.failedAt(for: session.id).map { (session.id, $0) }
        })
        let viewed = Dictionary(uniqueKeysWithValues: sessions.compactMap { session in
            readStateStore.lastViewedAt(for: session.id).map { (session.id, $0) }
        })
        return Self.failureCountsBySession(sessions: sessions, failedAt: failed, lastViewedAt: viewed)
    }

    /// One derivation per rendering boundary; cells consume values only.
    var sessionIndicatorPresentations: [String: SessionIndicatorPresentation] {
        let now = max(Date(), statusEvaluationDate)
        let unread = sessionUnreadCounts
        let failures = sessionFailureCounts
        let attention = sessionAttentionCounts
        let known = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        var active: [String: SessionStatus] = [:]
        var unknownIDs: [String] = []
        // The status poll covers only the sessions of the effective project
        // directory. A session outside it is never confirmed — that is "not
        // tracked", not "awaiting sync": claiming the latter left the row
        // stuck on "Status awaiting sync" forever. An uninterpretable status
        // type still defers the unread, so latent reminders are not swallowed.
        let polledDirectory = effectiveProjectDirectory ?? serverCurrentProjectWorktree
        for session in sessions {
            let inPolledDirectory = polledDirectory == nil || session.directory == polledDirectory
            let confirmed = statusConfirmedAt[session.id].map { now.timeIntervalSince($0) < 60 } == true
            let fresh = statusStreamConnected && isConnected && inPolledDirectory && confirmed
            let type = sessionStatuses[session.id]?.type
            let unknownType = type != nil && type != "idle" && type != "busy" && type != "retry"
            if unknownType || (inPolledDirectory && (!fresh || !confirmed)) {
                unknownIDs.append(session.id)
            } else if let status = sessionStatuses[session.id], isBusySession(status) {
                active[session.id] = status
            }
        }
        let descendants = Self.descendantBusyCountsBySession(sessions: sessions, sessionStatuses: active)
        let unknown = Self.attentionCountsBySession(sessions: sessions, attentionSessionIDs: unknownIDs)
        // An active ID without metadata cannot safely be assigned to a tree.
        let directory = effectiveProjectDirectory ?? serverCurrentProjectWorktree
        let unplacedActive = sessionStatuses.contains { id, status in
            guard isConnected, statusStreamConnected, isBusySession(status),
                  let directory,
                  (statusDirectories[id] ?? known[id]?.directory) == directory,
                  statusConfirmedAt[id].map({ now.timeIntervalSince($0) < 60 }) == true else { return false }
            var next: String? = id
            var visited: Set<String> = []
            while let source = next, visited.insert(source).inserted {
                guard let session = known[source] else { return true }
                next = session.parentID
            }
            return next != nil // Broken or cyclic active ancestry cannot prove a tree stopped.
        }
        return Dictionary(uniqueKeysWithValues: sessions.map { session in
            let own = active[session.id]
            let count = descendants[session.id, default: 0]
            let needsSync = unknown[session.id, default: 0] > 0 || unplacedActive
            let indicator: SessionIndicator?
            if session.isArchived { indicator = nil }
            else if attention[session.id, default: 0] > 0 { indicator = .needsYou }
            else if failures[session.id, default: 0] > 0 { indicator = .failed }
            else if own != nil || count > 0 { indicator = .running }
            else if !needsSync && session.id != currentSessionID && unread[session.id, default: 0] > 0 { indicator = .unread }
            else { indicator = nil }
            return (session.id, SessionIndicatorPresentation(indicator: indicator, needsSync: needsSync,
                        ownIsRetrying: own?.type == "retry", activeDescendantCount: count, ownIsActive: own != nil))
        })
    }

    nonisolated static func attentionCountsBySession(
        sessions: [Session],
        attentionSessionIDs: [String]
    ) -> [String: Int] {
        let sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        var counts: [String: Int] = [:]

        for sourceSessionID in attentionSessionIDs {
            var sessionID: String? = sourceSessionID
            var visited: Set<String> = []
            while let currentSessionID = sessionID, visited.insert(currentSessionID).inserted {
                counts[currentSessionID, default: 0] += 1
                sessionID = sessionsByID[currentSessionID]?.parentID
            }
        }
        return counts
    }

    /// Aggregates running descendant subagents up the `parentID` chain: each
    /// session gets the count of busy sessions strictly below it in the loaded
    /// tree. Counting walks through idle intermediate ancestors, so
    /// a session never contributes to its own count in a valid tree and a running chain is
    /// counted once per ancestor. Cycle-safe; scoped to the loaded `sessions`
    /// list (the global status map may carry other projects).
    nonisolated static func descendantBusyCountsBySession(
        sessions: [Session],
        sessionStatuses: [String: SessionStatus]
    ) -> [String: Int] {
        let sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        func isBusy(_ id: String) -> Bool {
            guard let type = sessionStatuses[id]?.type else { return false }
            return type == "busy" || type == "retry"
        }

        var counts: [String: Int] = [:]
        for session in sessions where isBusy(session.id) {
            var ancestorID = sessionsByID[session.id]?.parentID
            var visited: Set<String> = []
            while let current = ancestorID, visited.insert(current).inserted {
                counts[current, default: 0] += 1
                ancestorID = sessionsByID[current]?.parentID
            }
        }
        return counts
    }

    nonisolated static func prioritizeAttention(
        _ nodes: [SessionNode],
        attentionCounts: [String: Int],
        descendantBusyCounts: [String: Int] = [:]
    ) -> [SessionNode] {
        nodes
            .map { node in
                SessionNode(
                    session: node.session,
                    children: prioritizeAttention(
                        node.children,
                        attentionCounts: attentionCounts,
                        descendantBusyCounts: descendantBusyCounts
                    )
                )
            }
            // The sort closure is nonisolated, so the flags are resolved
            // before it runs: reading the node ids inside would cross the
            // actor boundary.
            .map { node -> (SessionNode, Bool, Int) in
                let surfaces = attentionCounts[node.id, default: 0] > 0
                    || descendantBusyCounts[node.id, default: 0] > 0
                return (node, surfaces, node.session.time.updated)
            }
            .sorted { lhs, rhs in
                // A collapsed row hides its children, so a tree whose delegated
                // work is still running must surface by its parent row the same
                // way an attention-needing tree does.
                if lhs.1 != rhs.1 {
                    return lhs.1
                }
                return lhs.2 > rhs.2
            }
            .map(\.0)
    }

    var currentSession: Session? {
        guard let id = currentSessionID else { return nil }
        return sessions.first { $0.id == id }
    }

    var currentSessionStatus: SessionStatus? {
        guard let id = currentSessionID else { return nil }
        return sessionStatuses[id]
    }

    var isBusy: Bool {
        isBusySession(currentSessionStatus)
    }

    var currentTodos: [TodoItem] {
        guard let id = currentSessionID else { return [] }
        return sessionTodos[id] ?? []
    }

    /// 是否应处理 message.updated：有 sessionID 时需匹配当前 session，否则保持原行为
    nonisolated static func shouldProcessMessageEvent(eventSessionID: String?, currentSessionID: String?) -> Bool {
        guard currentSessionID != nil else { return false }
        if let sid = eventSessionID { return sid == currentSessionID }
        return true  // 无 sessionID 时保持原行为（向后兼容）
    }

    /// Async request result should only apply when requested session is still current.
    nonisolated static func shouldApplySessionScopedResult(requestedSessionID: String, currentSessionID: String?) -> Bool {
        requestedSessionID == currentSessionID
    }

    func refresh() async {
        await testConnection()
        if isConnected {
            async let agentsResult: Void = loadAgents()
            async let providersResult: Void = loadProvidersConfig()
            async let projectsResult: Void = loadProjects()
            await loadSessions()
            _ = await agentsResult
            _ = await providersResult
            _ = await projectsResult
            await loadMessages()
            await refreshPendingPermissions()
            await loadSessionDiff()
            await loadSessionTodos()
            await loadFileTree()
            await loadFileStatus()
            await syncSessionStatusesFromPoll()
        }
    }

    func loadProvidersConfig() async {
        let snapshot = captureHostRequestSnapshot()
        do {
            let resp = try await apiClient.providers()
            guard isCurrentHostRequest(snapshot) else { return }
            providersResponse = resp
            providerConfigError = nil
            var idx: [String: ProviderModel] = [:]
            for p in resp.providers {
                for (modelID, m) in p.models {
                    let key = "\(p.id)/\(modelID)"
                    idx[key] = m
                }
            }
            providerModelsIndex = idx
        } catch {
            guard isCurrentHostRequest(snapshot) else { return }
            providerConfigError = error.localizedDescription
        }

        guard isCurrentHostRequest(snapshot) else { return }
        if let registry = try? await apiClient.providerRegistry() {
            guard isCurrentHostRequest(snapshot) else { return }
            rebuildDynamicModelPresets(from: registry)
        } else if catalogModelPresets.isEmpty {
            Self.logger.warning("loadProvidersConfig: /provider registry unavailable, catalog unchanged")
        }
    }

    /// Builds the Settings catalog from connected chat-capable models.
    /// The chat picker reads `modelShortlist`, not this list.
    func rebuildDynamicModelPresets(from registry: ProviderRegistryResponse) {
        let connected = Set(registry.connectedProviderIDs)
        var names: [String: String] = [:]
        var presets: [ModelPreset] = []
        for provider in registry.providers where connected.contains(provider.id) {
            if let n = provider.name, !n.isEmpty { names[provider.id] = n }
            for (modelID, model) in provider.models.sorted(by: { $0.key < $1.key }) {
                guard model.capabilities?.isChatCapable ?? true else { continue }
                presets.append(
                    ModelPreset(
                        displayName: model.name ?? modelID,
                        providerID: provider.id,
                        modelID: modelID
                    )
                )
            }
        }
        presets.sort { a, b in
            if a.providerID != b.providerID { return a.providerID < b.providerID }
            return a.displayName < b.displayName
        }
        catalogModelPresets = presets
        providerDisplayNames = names
        refreshShortlistDisplayNames(from: presets)
        reanchorSelectedModelIndex()
        rebuildPickerModelItems(reason: "catalog")
    }

    func revealModelShortlistInSettings() {
        settingsFocus = .modelShortlist
        selectedTab = RootTab.settings.rawValue
    }

    func persistModelShortlist() {
        if let data = try? JSONEncoder().encode(modelShortlist) {
            defaults.set(data, forKey: Self.modelShortlistKey)
        }
    }

    func addModelsToShortlist(_ presets: [ModelPreset]) {
        var existing = Set(modelShortlist.map(\.id))
        var next = modelShortlist
        for preset in presets where !existing.contains(preset.id) {
            next.append(ModelShortlistItem.from(preset))
            existing.insert(preset.id)
        }
        guard next.count != modelShortlist.count else { return }
        modelShortlist = next
        reanchorSelectedModelIndex()
    }

    func removeShortlistItem(id: String) {
        modelShortlist.removeAll { $0.id == id }
        reanchorSelectedModelIndex()
    }

    func moveShortlist(from source: IndexSet, to destination: Int) {
        var next = modelShortlist
        let moving = source.sorted().map { next[$0] }
        for index in source.sorted().reversed() {
            next.remove(at: index)
        }
        let dest = min(max(destination - source.filter { $0 < destination }.count, 0), next.count)
        next.insert(contentsOf: moving, at: dest)
        modelShortlist = next
        reanchorSelectedModelIndex()
    }

    func updateShortlistShortName(id: String, shortName: String) {
        guard let idx = modelShortlist.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = shortName.trimmingCharacters(in: .whitespacesAndNewlines)
        var item = modelShortlist[idx]
        item.shortName = trimmed.isEmpty ? ModelPreset.suggestedShortName(for: item.displayName) : trimmed
        modelShortlist[idx] = item
    }

    private func refreshShortlistDisplayNames(from catalog: [ModelPreset]) {
        guard !modelShortlist.isEmpty else { return }
        let names = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0.displayName) })
        var changed = false
        var next = modelShortlist
        for i in next.indices {
            if let name = names[next[i].id], name != next[i].displayName {
                next[i].displayName = name
                changed = true
            }
        }
        if changed { modelShortlist = next }
    }

    /// Rebuilds the flat picker rows (provider header + models) from the
    /// current picker source list and search text. AppState-backed so the
    /// sheet observes it directly.
    func rebuildPickerModelItems(reason: String) {
        let query = modelSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = pickerModelPresets.enumerated().filter { _, preset in
            query.isEmpty
                || preset.displayName.lowercased().contains(query)
                || preset.modelID.lowercased().contains(query)
                || preset.providerID.lowercased().contains(query)
        }
        pickerModelItems = filtered.map { ModelPickerItem.model(index: $0.offset, preset: $0.element) }
        pickerModelGen += 1
    }

    /// After the picker list is rebuilt, point `selectedModelIndex` at the
    /// same model in the new list (or the canonical successor for aged ids).
    private func reanchorSelectedModelIndex() {
        let savedID = currentSessionID.flatMap { selectedModelIDBySessionID[$0] }
            ?? selectedModel.map { $0.id }
            ?? pickerModelPresets.first?.id
        guard let savedID else { return }
        let canonical = canonicalModelPresetID(for: savedID)
        if let idx = pickerModelPresets.firstIndex(where: { $0.id == canonical }) {
            selectedModelIndex = idx
        } else if !pickerModelPresets.isEmpty {
            selectedModelIndex = 0
        }
    }

}

struct PendingPermission: Identifiable {
    var id: String { "\(sessionID)/\(permissionID)" }
    let sessionID: String
    let permissionID: String
    let permission: String?
    let patterns: [String]
    let allowAlways: Bool
    let tool: String?
    let description: String
}

struct SessionActivity: Identifiable {
    enum State {
        case running
        case completed
    }

    var id: String { sessionID }
    let sessionID: String
    var state: State
    var text: String
    let startedAt: Date
    var endedAt: Date?
    var anchorMessageID: String?

    func elapsedSeconds(now: Date = Date()) -> Int {
        let end = endedAt ?? now
        return max(0, Int(end.timeIntervalSince(startedAt)))
    }

    func elapsedString(now: Date = Date()) -> String {
        let secs = elapsedSeconds(now: now)
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }
}
