//
//  AppState+ProjectMemory.swift
//  OpenCodeClient
//

import Foundation

/// The state behind the Project Memory panel: the `AGENTS.md` file the OpenCode server injects
/// into every provider turn.
///
/// The client reads it and asks the agent to improve it. It never writes it: there is no endpoint
/// that lets a client write a workspace file, and the agent owns file writes.
///
/// Spec: docs/features/project_memory/design.md
extension AppState {

    /// How far up the directory tree the client looks for the instruction file.
    ///
    /// The server walks up from the session's directory to the project root. The client walks the
    /// same way, so the panel shows the memory the agent actually gets — not a different file
    /// that happens to share the name.
    static let projectMemorySearchDepth = 8

    /// The panel's state.
    var projectMemory: ProjectMemoryModel {
        get { fileStore.projectMemory }
        set { fileStore.projectMemory = newValue }
    }

    /// The directories to look for the instruction file in, nearest first.
    ///
    /// The search starts at the session's directory — the server loads instructions relative to
    /// it — and walks up to the project root. With no project root known it stops at the file
    /// system's root or the depth cap, whichever comes first.
    var projectMemorySearchPaths: [String] {
        let start = currentSession?.directory ?? effectiveProjectDirectory ?? serverCurrentProjectWorktree
        guard let start, !start.isEmpty else { return [] }
        let bound = projectMemorySearchBound
        var paths: [String] = []
        var current = start
        while paths.count < Self.projectMemorySearchDepth {
            paths.append(current)
            if let bound, current == bound { break }
            let parent = (current as NSString).deletingLastPathComponent
            if parent.isEmpty || parent == current { break }
            current = parent
        }
        return paths
    }

    /// The directory the search stops at: the project root the server would use.
    ///
    /// The server loads instructions between the session's directory and the project root, so
    /// the client has to stop at the same place — otherwise it would walk past the project and
    /// read a file that belongs to something else.
    var projectMemorySearchBound: String? {
        if let selected = effectiveProjectDirectory, !selected.isEmpty { return selected }
        if let current = serverCurrentProjectWorktree, !current.isEmpty { return current }
        guard let start = currentSession?.directory, !start.isEmpty else { return nil }
        // The session's directory is the project root unless a known project contains it.
        return projects
            .map(\.worktree)
            .filter { !$0.isEmpty && ($0 == start || start.hasPrefix($0 + "/")) }
            .max(by: { $0.count < $1.count })
    }

    // MARK: - Reading

    /// Read the instruction file.
    ///
    /// The baseline is the version the user has accepted. It is captured on the first settled
    /// read of a directory and only advances when the user accepts a change — so a rewrite the
    /// agent did while the user was elsewhere is still visible as a diff.
    func loadProjectMemory() async {
        let host = captureHostRequestSnapshot()
        let paths = projectMemorySearchPaths
        let root = paths.first

        projectMemory.loadGeneration &+= 1
        let generation = projectMemory.loadGeneration

        if projectMemory.searchRoot != root {
            // A different directory means a different file, so the writes noted for the old one
            // say nothing about this one, and the baseline belongs to the old file.
            projectMemory.notedWritePartIDs = []
            projectMemory.baseline = nil
        }
        projectMemory.content = .loading

        let result = await readInstructionFileSearching(paths: paths)

        guard isCurrentHostRequest(host) else { return }
        guard generation == projectMemory.loadGeneration else { return }
        guard projectMemorySearchPaths.first == root else { return }
        // A cancelled read leaves the client without an answer, so it must not claim to have
        // loaded anything — and must not poison the "read once" cache.
        if case .cancelled = result.outcome { return }

        projectMemory.content = Self.projectMemoryContent(for: result.outcome)
        projectMemory.loadedDirectory = result.directory
        projectMemory.searchRoot = root
        projectMemory.hasLoaded = true
        if projectMemory.baseline == nil {
            projectMemory.baseline = projectMemory.settledSnapshot
        }
    }

    /// Read the instruction file once per directory.
    ///
    /// The Files tab states whether the project has memory, so the file is read when the tab
    /// appears — but only once per directory, and never again for a directory already read.
    func loadProjectMemoryIfNeeded() async {
        let root = projectMemorySearchPaths.first
        guard !projectMemory.hasLoaded || projectMemory.searchRoot != root else { return }
        await loadProjectMemory()
    }

    /// Look for the instruction file, walking up from the nearest directory.
    ///
    /// A directory that does not hold the file is not a failure: the search keeps going. A
    /// directory that holds it but cannot be read is a failure, and the search stops.
    private func readInstructionFileSearching(paths: [String]) async -> (outcome: ProjectMemoryReadOutcome, directory: String?) {
        if paths.isEmpty {
            // Nothing is known about the workspace: ask the server for its default.
            return (await readInstructionFile(from: nil), nil)
        }
        for directory in paths {
            let outcome = await readInstructionFile(from: directory)
            switch outcome {
            case .notFound:
                continue
            case .found, .failed, .cancelled:
                return (outcome, directory)
            }
        }
        // Nothing held the file. The last directory searched is where the server would have
        // looked, so the panel can name it instead of saying "the server's default".
        return (.notFound, paths.last)
    }

    /// One read of the instruction file from one directory.
    private func readInstructionFile(from directory: String?) async -> ProjectMemoryReadOutcome {
        do {
            let content = try await loadFileContent(
                path: ProjectMemoryFile.instructionFileName,
                workspaceDirectory: directory
            )
            if let text = content.text {
                return .found(text)
            }
            // The server answered with a file it could not read as text.
            return .failed(.binary)
        } catch APIError.httpError(let statusCode, _) where statusCode == 404 {
            return .notFound
        } catch {
            if error is CancellationError { return .cancelled }
            if case APIError.httpError(let statusCode, _) = error {
                return .failed(.transport("HTTP \(statusCode)"))
            }
            if let decodingError = error as? DecodingError {
                // A body the client could not decode is not a missing file.
                return .failed(.transport(String(describing: decodingError)))
            }
            return .failed(.transport(error.localizedDescription))
        }
    }

    /// The content state for a read.
    nonisolated static func projectMemoryContent(for outcome: ProjectMemoryReadOutcome) -> ProjectMemoryModel.Content {
        switch outcome {
        case .found(let text):
            return .text(text)
        case .notFound:
            return .absent
        case .failed(let failure):
            return .unreadable(failure)
        case .cancelled:
            return .notLoaded
        }
    }

    /// Accept the version on the server: it becomes the baseline the next change is measured
    /// against.
    ///
    /// The file on the server is already the new version — accepting only decides whether the
    /// client keeps reporting the change.
    func acceptProjectMemoryChange() {
        guard let snapshot = projectMemory.settledSnapshot else { return }
        projectMemory.baseline = snapshot
    }

    // MARK: - Freshness

    /// Re-read the instruction file when the agent wrote it.
    ///
    /// Called from the file-change refresh, which is already debounced, so the file is not read
    /// while the agent is still writing it. The refresh is skipped when the file was never read:
    /// a panel nobody looked at does not earn a read.
    func refreshProjectMemoryIfChanged() async {
        guard projectMemory.hasLoaded else { return }
        let writes = ProjectMemoryChangeScanner.instructionFileWrites(in: messages)
        let fresh = writes.filter { !projectMemory.notedWritePartIDs.contains($0) }
        guard !fresh.isEmpty else { return }
        await loadProjectMemory()
        // The writes are only noted once the read landed: a failed read has to be retried.
        projectMemory.notedWritePartIDs.formUnion(fresh)
    }

    /// True while the agent may be rewriting the instruction file.
    ///
    /// The dispatch latch covers the moment between the request and the session reporting itself
    /// busy; the session status covers the rest of the turn.
    var projectMemoryAgentIsWorking: Bool {
        if projectMemory.pendingAction { return true }
        guard let sessionID = currentSessionID else { return false }
        return isBusySession(sessionStatuses[sessionID])
    }

    /// Settle a dispatched action once the turn has run.
    ///
    /// The action is cleared when the session has been busy and then stopped — not when the
    /// request was merely accepted, which happens before the turn starts.
    func updateProjectMemoryActionState() {
        guard projectMemory.pendingAction else { return }
        guard let sessionID = currentSessionID else {
            projectMemory.pendingAction = false
            return
        }
        if isBusySession(sessionStatuses[sessionID]) {
            projectMemory.sawBusySinceDispatch = true
            return
        }
        guard projectMemory.sawBusySinceDispatch else { return }
        projectMemory.pendingAction = false
        projectMemory.sawBusySinceDispatch = false
    }

    // MARK: - Actions

    /// Ask the agent to bring the instruction file up to date.
    ///
    /// The prompt goes into the current session through the ordinary prompt path, so the agent's
    /// reasoning stays visible. Instruction mutation is a privileged operation; making it
    /// auditable is the point.
    func improveProjectMemory() async -> Bool {
        guard canRunProjectMemoryAction else { return false }
        projectMemory.pendingAction = true
        projectMemory.sawBusySinceDispatch = false
        let sent = await sendMessage(ProjectMemoryPrompt.improve)
        if !sent {
            // Nothing was dispatched, so nothing has to settle.
            projectMemory.pendingAction = false
        }
        return sent
    }

    /// Ask the agent to put the accepted version back.
    ///
    /// The client cannot write the file, so a restore is a request. The panel says so rather than
    /// implying a guaranteed revert.
    func restoreProjectMemory() async -> Bool {
        guard canRunProjectMemoryAction else { return false }
        guard let previous = projectMemory.baseline?.text else { return false }
        projectMemory.pendingAction = true
        projectMemory.sawBusySinceDispatch = false
        let sent = await sendMessage(ProjectMemoryPrompt.restore(previous: previous))
        if !sent {
            projectMemory.pendingAction = false
        }
        return sent
    }

    /// Whether an action can run right now.
    ///
    /// A prompt sent into a running session is queued by the server, and its position in the
    /// conversation is unpredictable — so the action waits for the session to settle.
    var canRunProjectMemoryAction: Bool {
        guard let sessionID = currentSessionID else { return false }
        guard !projectMemory.pendingAction else { return false }
        return !isBusySession(sessionStatuses[sessionID])
    }
}

/// What one read produced.
nonisolated enum ProjectMemoryReadOutcome: Equatable, Sendable {
    /// The file was read and it is text.
    case found(String)
    /// There is no such file here.
    case notFound
    /// The file is there but could not be used.
    case failed(ProjectMemoryFailure)
    /// The read was cancelled — most often because the view went away.
    case cancelled
}
