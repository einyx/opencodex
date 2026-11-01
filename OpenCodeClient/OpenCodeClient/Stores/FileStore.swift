//
//  FileStore.swift
//  OpenCodeClient
//

import Foundation
import Observation

@Observable
final class FileStore {
    var sessionDiffs: [FileDiff] = []
    var selectedDiffFile: String?
    /// The changes surface's request.
    var changesPreview: AppState.SessionChangesPreview?
    /// Diffs of the turns that changed files, keyed by the user message that
    /// started the turn.
    var turnDiffs: [String: [FileDiff]] = [:]
    /// The pending refresh of the file state after the agent wrote.
    @ObservationIgnored var fileChangeRefreshTask: Task<Void, Never>?
    /// The change/write parts whose refresh has already been scheduled.
    @ObservationIgnored var notedChangePartIDs: Set<String> = []
    var fileTreeRoot: [FileNode] = []
    var fileTreeError: String?
    var isLoadingFileTree = false
    var fileTreeLoadGeneration: UInt64 = 0
    var fileChildrenErrors: [String: String] = [:]
    var fileStatusMap: [String: String] = [:]
    var expandedPaths: Set<String> = []
    var fileChildrenCache: [String: [FileNode]] = [:]
    var fileChildrenScope: FileChildrenScope?
    var fileChildrenLoadGeneration: [String: UInt64] = [:]
    var fileSearchQuery: String = ""
    var fileSearchResults: [String] = []
    var fileSearchGeneration: UInt64 = 0
    var fileSearchInFlight = false
    var fileSearchFailed = false
    var fileSearchError: String?
    var fileSearchOwner: HostRequestSnapshot?
    var fileSearchDirectory: String?
    /// The project's instruction file — the memory the server injects into every turn.
    var projectMemory: ProjectMemoryModel = ProjectMemoryModel()
}

struct FileChildrenScope: Equatable {
    var host: HostRequestSnapshot
    var directory: String?
}
