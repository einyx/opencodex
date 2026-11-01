//
//  AppState+FileChanges.swift
//  OpenCodeClient
//
//  The state behind the "files changed" surface: the turn-scoped diffs, the
//  refresh that keeps the file tree honest while the agent writes, and the
//  request that opens the changes surface.
//
//  Spec: docs/features/file_changes_surface/design.md
//

import Foundation
import os

extension AppState {

    /// Where the changes surface was opened from.
    enum ChangesPreviewHost: Equatable {
        /// Opened from a chat turn's change card.
        case chat
        /// Opened from the Files tab's Changes section.
        case files
    }

    /// What the changes surface is showing.
    struct SessionChangesPreview: Equatable, Identifiable {
        /// Where the surface was opened from.
        let host: ChangesPreviewHost
        /// The session the change belongs to.
        let sessionID: String?
        /// The user message that started the turn, when the scope is a turn.
        let turnUserMessageID: String?
        /// The changed paths.
        let paths: [String]
        /// The workspace the paths are relative to.
        let workspaceDirectory: String?

        var id: String {
            "\(host == .chat ? "chat" : "files")|\(sessionID ?? "-")|\(turnUserMessageID ?? "-")|\(paths.joined(separator: ","))"
        }
    }

    var changesPreview: SessionChangesPreview? {
        get { fileStore.changesPreview }
        set { fileStore.changesPreview = newValue }
    }

    /// Diffs of the turns that changed files, keyed by the user message that
    /// started the turn.
    var turnDiffs: [String: [FileDiff]] {
        get { fileStore.turnDiffs }
        set { fileStore.turnDiffs = newValue }
    }

    /// The diffs of a turn, when they have been loaded.
    func diffs(forTurn turnUserMessageID: String?) -> [FileDiff] {
        guard let turnUserMessageID else { return [] }
        return turnDiffs[turnUserMessageID] ?? []
    }

    // MARK: - Presenting

    func presentSessionChanges(
        host: ChangesPreviewHost,
        sessionID: String?,
        turnUserMessageID: String?,
        paths: [String],
        workspaceDirectory: String?
    ) {
        guard !paths.isEmpty else { return }
        changesPreview = SessionChangesPreview(
            host: host,
            sessionID: sessionID,
            turnUserMessageID: turnUserMessageID,
            paths: paths,
            workspaceDirectory: workspaceDirectory
        )
    }

    func closeSessionChanges() {
        changesPreview = nil
    }

    // MARK: - Totals

    /// The totals a change card shows.
    ///
    /// The turn's diff is authoritative when it has loaded. Otherwise the
    /// part's own per-file counts are used (V1 patch parts carry them), and
    /// when neither is known the card shows the file count alone rather than
    /// a misleading zero.
    func fileChangeTotals(turnUserMessageID: String?, part: Part) -> FileChangeTotals? {
        let turnDiff = turnUserMessageID.flatMap { turnDiffs[$0] }
        return FileChangeTotals.resolve(turnDiff: turnDiff, part: part)
    }

    // MARK: - Write signals

    /// Note the file-change signals in a loaded transcript.
    ///
    /// A patch part is the "files changed" signal; a write/edit tool part is
    /// the signal that files may have changed even when the server sent no
    /// patch. Either one means the file tree and status can be stale.
    func noteFileChangeSignals(sessionID: String, messages: [MessageWithParts]) {
        for signal in FileChangeSignalScanner.signals(in: messages) {
            noteFileChangeSignal(
                partID: signal.partID,
                sessionID: sessionID,
                turnUserMessageID: signal.turnUserMessageID
            )
        }
    }

    /// Record one file-change signal and refresh the file state.
    ///
    /// A transcript keeps the change parts of every past turn. Only a signal
    /// that has not been seen refreshes the file state, so reloading an old
    /// transcript does not.
    func noteFileChangeSignal(partID: String, sessionID: String, turnUserMessageID: String?) {
        guard currentSessionID == sessionID else { return }
        guard !fileStore.notedChangePartIDs.contains(partID) else { return }
        fileStore.notedChangePartIDs.insert(partID)
        scheduleFileChangeRefresh()
        guard let turnUserMessageID else { return }
        Task { [weak self] in
            await self?.loadTurnDiff(turnUserMessageID: turnUserMessageID, sessionID: sessionID)
        }
    }

    /// Load the diff of one turn.
    ///
    /// Only V2 can scope a diff to a turn; V1 answers with the whole session,
    /// which would misreport a per-turn card, so V1 keeps the part's own
    /// counts instead.
    func loadTurnDiff(turnUserMessageID: String, sessionID: String) async {
        let generation = await apiClient.currentGeneration()
        guard generation == .v2 else { return }
        let host = captureHostRequestSnapshot()
        do {
            let diffs = try await apiClient.sessionDiff(
                sessionID: sessionID,
                from: turnUserMessageID,
                to: nil,
                context: nil
            )
            guard isCurrentHostRequest(host), currentSessionID == sessionID else { return }
            turnDiffs[turnUserMessageID] = diffs
        } catch {
            // A missing turn diff is not fatal: the card still states how many
            // files changed, and the surface shows its own loading state.
            Self.logger.debug("loadTurnDiff failed: session=\(sessionID, privacy: .public) turn=\(turnUserMessageID, privacy: .public)")
        }
    }

    // MARK: - Freshness

    /// Schedule a refresh of the file state.
    ///
    /// Several writes in one turn collapse into one refresh: the tree, the
    /// status map and the session diff are re-read together, once the writes
    /// have settled.
    func scheduleFileChangeRefresh() {
        fileStore.fileChangeRefreshTask?.cancel()
        fileStore.fileChangeRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await self?.refreshFileChangeState()
        }
    }

    /// Re-read the file state after the agent wrote.
    func refreshFileChangeState() async {
        await loadSessionDiff()
        await loadFileStatus()
        // The tree is only re-read when it is on screen: a chat-only session
        // has no reason to walk the project directory.
        if !fileTreeRoot.isEmpty {
            await loadFileTree()
        }
        // The instruction file is a file like any other: when the agent writes
        // it, the Project Memory panel has to show the new version.
        await refreshProjectMemoryIfChanged()
    }
}
