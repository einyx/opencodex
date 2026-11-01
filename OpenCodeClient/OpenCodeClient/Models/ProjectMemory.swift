//
//  ProjectMemory.swift
//  OpenCodeClient
//

import Foundation

/// The project's instruction file — the one piece of memory the OpenCode server owns and
/// injects into every provider turn.
///
/// The client never writes it: the agent does, through its normal file tools. The client reads
/// the file, shows it, and asks the agent to improve it.
///
/// Spec: docs/features/project_memory/design.md

/// The instruction file the server reads at the project root.
nonisolated enum ProjectMemoryFile {
    /// The file name the server looks for.
    static let instructionFileName = "AGENTS.md"
}

/// Why the instruction file could not be used.
nonisolated enum ProjectMemoryFailure: Equatable, Sendable {
    /// The file exists but is not UTF-8 text.
    case binary
    /// The read failed: the server was unreachable, refused the request, or answered with
    /// something the client could not read.
    case transport(String)
}

/// What the user saw.
///
/// A snapshot with no text means the file was absent. That is different from "never captured",
/// which is what a missing baseline means.
nonisolated struct ProjectMemorySnapshot: Equatable, Sendable {
    /// The file's text, or nil when there was no instruction file.
    var text: String?

    /// The file was not there.
    static let absent = ProjectMemorySnapshot(text: nil)
}

/// Everything the panel shows.
///
/// One value holds the content, the baseline and the read bookkeeping, so a read and a baseline
/// can never be observed half-updated. Every mutation is a whole-struct write on the main actor,
/// so a mutation cannot interleave with another.
nonisolated struct ProjectMemoryModel: Equatable, Sendable {
    /// The content of the instruction file, as far as the client knows it.
    enum Content: Equatable, Sendable {
        /// Not read yet.
        case notLoaded
        /// A read is in flight.
        case loading
        /// There is no instruction file at or above the session's directory.
        case absent
        /// The file is there and is text.
        case text(String)
        /// The file is there but could not be used.
        case unreadable(ProjectMemoryFailure)
    }

    var content: Content = .notLoaded
    /// The version the user has accepted. A change is measured against it, so it only advances
    /// when the user accepts — a rewrite the agent did while the user was elsewhere stays
    /// visible as a diff.
    var baseline: ProjectMemorySnapshot?
    /// An agent turn is writing the file right now.
    ///
    /// Set when a request is dispatched and cleared when the turn settles. It is not cleared
    /// when the request is *accepted*: the server has not started the turn yet, and clearing it
    /// then would let a second tap send the same prompt twice.
    var pendingAction = false
    /// The session has been seen busy since the request was dispatched.
    var sawBusySinceDispatch = false
    /// The directory the last search started from. The file belongs to one project, so a
    /// different directory means a different file and a fresh search.
    var searchRoot: String?
    /// The directory the file was actually found in. `nil` means the server's default.
    var loadedDirectory: String?
    /// The file has been read at least once.
    ///
    /// This cannot be inferred from `searchRoot`: a root of `nil` means "the server's default
    /// directory", not "never read", and the two have to be told apart.
    var hasLoaded = false
    /// The parts whose write to the instruction file has already been seen. A transcript keeps
    /// the writes of every past turn, so without this the file would be re-read forever.
    var notedWritePartIDs: Set<String> = []
    /// The read generation, so a stale response cannot overwrite a newer one.
    var loadGeneration: UInt64 = 0

    /// The snapshot of the file, when the client actually knows it.
    ///
    /// "Unknown" is not the same as "absent": a read in flight and a read that failed both
    /// leave the client without an answer, and neither may be reported as a deletion.
    var settledSnapshot: ProjectMemorySnapshot? {
        switch content {
        case .text(let text):
            return ProjectMemorySnapshot(text: text)
        case .absent:
            return .absent
        case .notLoaded, .loading, .unreadable:
            return nil
        }
    }

    /// The file's text, when it could be read.
    var currentText: String? {
        if case .text(let text) = content { return text }
        return nil
    }

    /// True when the file differs from the accepted version.
    var hasChange: Bool {
        guard let baseline, let current = settledSnapshot else { return false }
        return baseline != current
    }

    /// True when the file was there and is gone now.
    var wasDeleted: Bool {
        guard let baseline, baseline.text != nil else { return false }
        guard let current = settledSnapshot else { return false }
        return current.text == nil
    }

    /// True when the file was not there and is now.
    var wasCreated: Bool {
        guard let baseline, baseline.text == nil else { return false }
        guard let current = settledSnapshot else { return false }
        return current.text != nil
    }
}

/// The prompts the panel sends.
///
/// The improve prompt mirrors the scope of the server's own `/init` command: high-signal, verified
/// facts only, never generic advice, and never a rewrite of what the user wrote.
nonisolated enum ProjectMemoryPrompt {
    /// Ask the agent to bring the instruction file up to date.
    static let improve = """
    Update this project's AGENTS.md.

    Read the existing file first and keep everything the user wrote. This file is injected into \
    every future session, so a hand-written rule that gets dropped is a regression nobody would \
    notice until much later.

    Add only the facts a future session would otherwise have to rediscover: the build, test and \
    lint commands that actually work (read them from the manifest and the CI config), where the \
    code lives, and the conventions that are not obvious from reading a single file.

    Do not add generic advice ("write clean code", "add tests"), do not restate what the \
    repository name already implies, and do not record anything you have not verified in the \
    repository. If you are unsure, leave it out.

    Finish by saying what you changed.
    """

    /// The markers the previous content is fenced between, so a restore prompt is unambiguous
    /// even when the file contains dashes or code fences of its own.
    nonisolated static let restoreBegin = "---BEGIN AGENTS.md---"
    nonisolated static let restoreEnd = "---END AGENTS.md---"

    /// Ask the agent to put the accepted version back.
    ///
    /// The client cannot write the file, so a restore is a request.
    static func restore(previous: String) -> String {
        """
        Restore this project's AGENTS.md to an earlier version.

        Rewrite the file so its content is exactly the text between the markers below, character \
        for character. Do not improve it, do not reformat it, and do not add anything of your \
        own.

        \(restoreBegin)
        \(previous)
        \(restoreEnd)
        """
    }
}

extension ProjectMemoryModel {
    /// How many lines the file has.
    ///
    /// One helper, because the Files tab and the panel both show the count and must not drift.
    static func lineCount(of text: String) -> Int {
        text.split(separator: "\n", omittingEmptySubsequences: false).count
    }
}

/// Finds the turns where the agent wrote the instruction file.
nonisolated enum ProjectMemoryChangeScanner {
    /// The ids of the parts that wrote the instruction file.
    ///
    /// The path is matched on its last component, so it does not matter whether the server
    /// reports it absolute or relative to the project root.
    static func instructionFileWrites(in messages: [MessageWithParts]) -> [String] {
        var writes: [String] = []
        for message in messages {
            guard message.info.role == "assistant" else { continue }
            for part in message.parts {
                guard ToolCardClassifier.isChangePart(part)
                    || ToolCardClassifier.isWriteOperation(part) else { continue }
                guard part.filePathsForNavigation.contains(where: isInstructionPath) else { continue }
                writes.append(part.id)
            }
        }
        return writes
    }

    private static func isInstructionPath(_ path: String) -> Bool {
        (path as NSString).lastPathComponent == ProjectMemoryFile.instructionFileName
    }
}
