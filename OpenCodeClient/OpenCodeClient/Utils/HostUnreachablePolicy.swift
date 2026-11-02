import Foundation

/// Whether the host cannot be reached.
///
/// The connection failed, or the app was left disconnected with an error to
/// explain. A check in flight is not evidence — the host may well be fine —
/// so it never counts as unreachable.
///
/// Two surfaces read this rule: the Settings connection section, which draws
/// the unplugged plug, and the session list, which must not claim an account
/// has no sessions when the truth is that nobody could ask. One rule, so the
/// two cannot drift apart.
nonisolated enum HostUnreachablePolicy {
    static func isUnreachable(
        isChecking: Bool,
        diagnostic: ConnectionDiagnostic?,
        connectionError: String?,
        isConnected: Bool
    ) -> Bool {
        if isChecking { return false }
        if diagnostic?.phase == .failed { return true }
        return connectionError != nil && !isConnected && diagnostic == nil
    }
}
