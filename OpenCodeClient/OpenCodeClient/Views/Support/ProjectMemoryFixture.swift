import Foundation
import SwiftUI

/// The Project Memory fixture: the Files tab with the project's instruction file.
///
/// It answers the one request the panel makes — reading `AGENTS.md` — so the panel can be
/// opened, read and reviewed without a server.
enum ProjectMemoryFixture {
    static let argument = "UITEST_PROJECT_MEMORY_FIXTURE"
    nonisolated static let modeKey = "PROJECT_MEMORY_FIXTURE_MODE"

    /// The workspace the fixture pretends to be in.
    static let workspace = "/tmp/project-memory-fixture"

    /// What the file looked like before the agent changed it.
    static let original = """
    # Project Memory Fixture

    ## Commands

    - Build: `xcodebuild build`
    - Test: `./scripts/test_unit.sh`

    ## Conventions

    - Swift naming follows the standard library.
    """

    /// What the agent wrote.
    static let updated = """
    # Project Memory Fixture

    ## Commands

    - Build: `xcodebuild build`
    - Test: `./scripts/test_unit.sh`
    - UI test: `./scripts/test_ui.sh`

    ## Conventions

    - Swift naming follows the standard library.
    - Every new feature gets a design doc under `docs/features/`.
    """

    enum Mode: String {
        /// The file is there and the agent has not touched it.
        case present
        /// There is no instruction file.
        case absent
        /// The agent rewrote the file, so the panel has a change to review.
        case changed
    }

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }

    nonisolated static var mode: Mode {
        let raw = ProcessInfo.processInfo.environment[modeKey] ?? Mode.present.rawValue
        return Mode(rawValue: raw) ?? .present
    }

    @MainActor
    static func makeAppState() -> AppState {
        let defaults = UITestFixtures.isolatedDefaults(label: "project-memory")
        return AppState(
            apiClient: StubClient(),
            sseClient: SSEClient(),
            sshTunnelManager: SSHTunnelManager(defaults: defaults),
            userDefaults: defaults,
            hostCredentialAccess: HostCredentialAccess(
                save: { _, _ in },
                load: { _ in nil },
                delete: { _ in }
            )
        )
    }

    @MainActor
    static func apply(to state: AppState) {
        state.isConnected = true
        state.selectedTab = RootTab.files.rawValue
        if ProcessInfo.processInfo.environment["UITEST_LAYOUT_PREFERENCE"] == "focus" {
            state.layoutPreference = .focus
        }
        state.selectedProjectWorktree = workspace
        state.sessions = [
            Session(
                id: "project-memory-session",
                slug: "project-memory-session",
                projectID: "p1",
                directory: workspace,
                parentID: nil,
                title: "Project memory",
                version: "1",
                time: .init(created: 1, updated: 2, archived: nil),
                share: nil,
                summary: nil
            )
        ]
        state.currentSessionID = "project-memory-session"
        state.fileTreeRoot = [
            FileNode(name: "AGENTS.md", path: "AGENTS.md", absolute: nil, type: "file", ignored: false)
        ]

        // The state the user has already seen, so the fixture does not depend on how many
        // times the Files tab reads the file before the panel opens.
        state.projectMemory.searchRoot = workspace
        state.projectMemory.hasLoaded = true
        switch mode {
        case .present:
            state.projectMemory.content = .text(original)
            state.projectMemory.baseline = ProjectMemorySnapshot(text: original)
        case .absent:
            state.projectMemory.content = .absent
            state.projectMemory.baseline = .absent
        case .changed:
            // The user saw the old version; the server now holds the agent's rewrite.
            state.projectMemory.content = .text(original)
            state.projectMemory.baseline = ProjectMemorySnapshot(text: original)
        }
    }

    actor StubClient: APIClientProtocol {
        func configure(baseURL: String, username: String?, password: String?) {}
        func health() async throws -> HealthResponse { HealthResponse(healthy: true, version: "fixture") }
        func projects() async throws -> [Project] { [] }
        func projectCurrent() async throws -> Project? { nil }
        func sessions(directory: String?, limit: Int) async throws -> [Session] { [] }
        func session(sessionID: String) async throws -> Session {
            throw APIError.httpError(statusCode: 404, data: Data())
        }
        func currentGeneration() -> ServerGeneration { .auto }
        func createSession(title: String?, directory: String?) async throws -> Session {
            throw APIError.httpError(statusCode: 501, data: Data())
        }
        func updateSession(sessionID: String, title: String) async throws -> Session {
            throw APIError.httpError(statusCode: 501, data: Data())
        }
        func updateSessionArchived(sessionID: String, archived: Int) async throws -> Session {
            throw APIError.httpError(statusCode: 501, data: Data())
        }
        func deleteSession(sessionID: String) async throws {}
        func messages(sessionID: String, limit: Int?) async throws -> [MessageWithParts] { [] }
        func promptAsync(sessionID: String, messageID: String, text: String, attachments: [ComposerImageAttachment], agent: String, model: Message.ModelInfo?, directory: String?) async throws {}
        func promptStructured(sessionID: String, messageID: String?, text: String, system: String, format: StructuredOutputFormat, agent: String, model: Message.ModelInfo) async throws -> MessageWithParts {
            throw APIError.httpError(statusCode: 501, data: Data())
        }
        func abort(sessionID: String) async throws {}
        func sessionStatus() async throws -> [String: SessionStatus] { [:] }
        func pendingPermissions() async throws -> [APIClient.PermissionRequest] { [] }
        func respondPermission(sessionID: String, permissionID: String, response: APIClient.PermissionResponse) async throws {}
        func pendingQuestions() async throws -> [QuestionRequest] { [] }
        func replyQuestion(requestID: String, answers: [[String]]) async throws {}
        func rejectQuestion(requestID: String) async throws {}
        func providers() async throws -> ProvidersResponse {
            try JSONDecoder().decode(ProvidersResponse.self, from: Data("{\"providers\":[]}".utf8))
        }
        func providerRegistry() async throws -> ProviderRegistryResponse {
            ProviderRegistryResponse(providers: [], connectedProviderIDs: [])
        }
        func agents() async throws -> [AgentInfo] { [] }
        func sessionDiff(sessionID: String) async throws -> [FileDiff] { [] }
        func sessionTodos(sessionID: String) async throws -> [TodoItem] { [] }
        func fileList(path: String, directory: String?) async throws -> [FileNode] {
            guard path.isEmpty else { return [] }
            return [FileNode(name: "AGENTS.md", path: "AGENTS.md", absolute: nil, type: "file", ignored: false)]
        }
        func fileContent(path: String, directory: String?) async throws -> FileContent {
            guard path == ProjectMemoryFile.instructionFileName else {
                throw APIError.httpError(statusCode: 404, data: Data())
            }
            switch ProjectMemoryFixture.mode {
            case .absent:
                throw APIError.httpError(statusCode: 404, data: Data())
            case .present:
                return FileContent(type: "text", content: ProjectMemoryFixture.original)
            case .changed:
                // The server holds the agent's rewrite; the user still has the old version as
                // the accepted baseline.
                return FileContent(type: "text", content: ProjectMemoryFixture.updated)
            }
        }
        func findFile(query: String, limit: Int) async throws -> [String] { [] }
        func fileStatus() async throws -> [FileStatusEntry] { [] }
        func forkSession(sessionID: String, messageID: String?) async throws -> Session {
            throw APIError.httpError(statusCode: 501, data: Data())
        }
        func revertSession(sessionID: String, messageID: String, partID: String?) async throws -> Session {
            throw APIError.httpError(statusCode: 501, data: Data())
        }
    }
}
