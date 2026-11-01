//
//  ProjectMemoryTests.swift
//  OpenCodeClientTests
//

import Foundation
import Testing
@testable import OpenCodeClient

/// The Project Memory panel: the `AGENTS.md` file the OpenCode server injects into every
/// provider turn, and the action that asks the agent to bring it up to date.
///
/// Spec: `docs/features/project_memory/design.md`
/// Plan: `docs/features/project_memory/plan.md`
struct ProjectMemoryTests {

    // MARK: - The wire mapping

    @Test func textContentBecomesText() {
        #expect(AppState.projectMemoryContent(for: .found("hello")) == .text("hello"))
    }

    @Test func aMissingFileIsAbsentAndNotAFailure() {
        #expect(AppState.projectMemoryContent(for: .notFound) == .absent)
    }

    @Test func anUnreadableFileIsUnreadable() {
        #expect(AppState.projectMemoryContent(for: .failed(.binary)) == .unreadable(.binary))
        #expect(AppState.projectMemoryContent(for: .failed(.transport("HTTP 503"))) == .unreadable(.transport("HTTP 503")))
    }

    @Test func aCancelledReadIsNotAnAnswer() {
        #expect(AppState.projectMemoryContent(for: .cancelled) == .notLoaded)
    }

    // MARK: - The settled snapshot

    @Test func aReadInFlightIsNotAChange() {
        var model = ProjectMemoryModel()
        model.baseline = ProjectMemorySnapshot(text: "# Project")
        model.content = .loading
        #expect(!model.hasChange)
        #expect(!model.wasDeleted)
        #expect(!model.wasCreated)
    }

    @Test func aFailedReadIsNotADeletion() {
        var model = ProjectMemoryModel()
        model.baseline = ProjectMemorySnapshot(text: "# Project")
        model.content = .unreadable(.transport("offline"))
        #expect(!model.hasChange)
        #expect(!model.wasDeleted)
        #expect(!model.wasCreated)
    }

    @Test func aFailedReadIsNotACreation() {
        var model = ProjectMemoryModel()
        model.baseline = .absent
        model.content = .unreadable(.transport("offline"))
        #expect(!model.hasChange)
        #expect(!model.wasCreated)
    }

    // MARK: - The baseline and the change

    @Test func anUnchangedFileIsNotAChange() {
        var model = ProjectMemoryModel()
        model.content = .text("# Project")
        model.baseline = ProjectMemorySnapshot(text: "# Project")
        #expect(!model.hasChange)
    }

    @Test func aChangedFileIsAChange() {
        var model = ProjectMemoryModel()
        model.content = .text("# Project\n\nBuild with make.")
        model.baseline = ProjectMemorySnapshot(text: "# Project")
        #expect(model.hasChange)
        #expect(!model.wasDeleted)
        #expect(!model.wasCreated)
    }

    @Test func aDeletedFileIsADeletion() {
        var model = ProjectMemoryModel()
        model.content = .absent
        model.baseline = ProjectMemorySnapshot(text: "# Project")
        #expect(model.wasDeleted)
        #expect(model.hasChange)
    }

    @Test func aCreatedFileIsACreation() {
        var model = ProjectMemoryModel()
        model.content = .text("# Project")
        model.baseline = .absent
        #expect(model.wasCreated)
        #expect(model.hasChange)
    }

    @Test func withoutABaselineNothingIsAChange() {
        var model = ProjectMemoryModel()
        model.content = .text("# Project")
        #expect(!model.hasChange)
    }

    // MARK: - Reading the file

    @Test @MainActor func theReadAsksForTheInstructionFileInTheSessionWorkspace() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.selectedProjectWorktree = "/work/proj"
        state.currentSessionID = "s1"
        state.sessions = [session(id: "s1", directory: "/work/proj")]

        await state.loadProjectMemory()

        #expect((await mock.fileContentRequests).count == 1)
        #expect((await mock.fileContentRequests).first?.path == "AGENTS.md")
        #expect((await mock.fileContentRequests).first?.directory == "/work/proj")
    }

    @Test @MainActor func aMissingFileReadsAsAbsent() async {
        let mock = MockAPIClient()
        await mock.setFileContent(error: APIError.httpError(statusCode: 404, data: Data()))
        let state = makeIsolatedAppState(apiClient: mock)
        state.selectedProjectWorktree = "/work/proj"
        state.currentSessionID = "s1"
        state.sessions = [session(id: "s1", directory: "/work/proj")]

        await state.loadProjectMemory()

        #expect(state.projectMemory.content == .absent)
        // The panel must name the directory the server would have looked in, not claim the
        // server's default directory was searched.
        #expect(state.projectMemory.loadedDirectory == "/work/proj")
    }

    @Test @MainActor func anotherStatusReadsAsUnreadable() async {
        let mock = MockAPIClient()
        await mock.setFileContent(error: APIError.httpError(statusCode: 503, data: Data()))
        let state = makeIsolatedAppState(apiClient: mock)
        state.selectedProjectWorktree = "/work/proj"
        state.currentSessionID = "s1"
        state.sessions = [session(id: "s1", directory: "/work/proj")]

        await state.loadProjectMemory()

        guard case .unreadable(.transport) = state.projectMemory.content else {
            Issue.record("a 503 must be unreadable, not absent")
            return
        }
    }

    @Test @MainActor func anUndecodableBodyIsNotAMissingFile() async {
        let mock = MockAPIClient()
        await mock.setFileContent(error: DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "not a file")
        ))
        let state = makeIsolatedAppState(apiClient: mock)
        state.selectedProjectWorktree = "/work/proj"
        state.currentSessionID = "s1"
        state.sessions = [session(id: "s1", directory: "/work/proj")]

        await state.loadProjectMemory()

        guard case .unreadable(.transport) = state.projectMemory.content else {
            Issue.record("an undecodable body must be unreadable, not absent")
            return
        }
    }

    @Test @MainActor func aFailedReadDoesNotCaptureAnAbsentBaseline() async {
        let mock = MockAPIClient()
        await mock.setFileContent(error: APIError.httpError(statusCode: 503, data: Data()))
        let state = makeIsolatedAppState(apiClient: mock)
        state.selectedProjectWorktree = "/work/proj"
        state.currentSessionID = "s1"
        state.sessions = [session(id: "s1", directory: "/work/proj")]

        await state.loadProjectMemory()
        #expect(state.projectMemory.baseline == nil)

        // The next good read must not look like the agent created the file.
        await mock.setFileContent(result: FileContent(type: "text", content: "# Project"))
        await state.loadProjectMemory()
        #expect(state.projectMemory.content == .text("# Project"))
        #expect(!state.projectMemory.wasCreated)
    }

    @Test @MainActor func theFileIsOnlyReadOncePerDirectory() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.selectedProjectWorktree = "/work/proj"

        await state.loadProjectMemoryIfNeeded()
        await state.loadProjectMemoryIfNeeded()

        #expect((await mock.fileContentRequests).count == 1)
    }

    @Test @MainActor func aDifferentDirectoryIsReadAgain() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.selectedProjectWorktree = "/work/one"
        state.currentSessionID = "s1"
        state.sessions = [session(id: "s1", directory: "/work/one")]
        await state.loadProjectMemoryIfNeeded()

        state.selectedProjectWorktree = "/work/two"
        state.sessions = [session(id: "s1", directory: "/work/two")]
        await state.loadProjectMemoryIfNeeded()

        #expect((await mock.fileContentRequests).count == 2)
    }

    @Test @MainActor func theBaselineIsClearedWhenTheDirectoryChanges() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.selectedProjectWorktree = "/work/one"
        state.currentSessionID = "s1"
        state.sessions = [session(id: "s1", directory: "/work/one")]
        await state.loadProjectMemory()
        #expect(state.projectMemory.baseline != nil)

        state.selectedProjectWorktree = "/work/two"
        state.sessions = [session(id: "s1", directory: "/work/two")]
        await state.loadProjectMemory()

        #expect(state.projectMemory.baseline == ProjectMemorySnapshot(text: ""))
    }

    @Test @MainActor func theBaselineSurvivesAReRead() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.selectedProjectWorktree = "/work/proj"
        state.currentSessionID = "s1"
        state.sessions = [session(id: "s1", directory: "/work/proj")]
        await state.loadProjectMemory()

        await state.loadProjectMemory()

        #expect(!state.projectMemory.hasChange)
    }

    // MARK: - The upward search

    @Test @MainActor func theSearchStartsAtTheSessionDirectoryAndStopsAtTheProjectRoot() {
        let state = makeIsolatedAppState()
        state.selectedProjectWorktree = "/work/proj"
        state.currentSessionID = "s1"
        state.sessions = [session(id: "s1", directory: "/work/proj/pkg")]

        #expect(state.projectMemorySearchPaths == ["/work/proj/pkg", "/work/proj"])
    }

    @Test @MainActor func theSearchStopsAtTheProjectRootWhenTheSessionIsThere() {
        let state = makeIsolatedAppState()
        state.selectedProjectWorktree = "/work/proj"
        state.currentSessionID = "s1"
        state.sessions = [session(id: "s1", directory: "/work/proj")]

        #expect(state.projectMemorySearchPaths == ["/work/proj"])
    }

    @Test @MainActor func theFileIsFoundInTheParentDirectory() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.selectedProjectWorktree = "/work/proj"
        state.currentSessionID = "s1"
        state.sessions = [session(id: "s1", directory: "/work/proj/pkg")]

        // The file is not in the session's directory, but it is in the project root.
        await mock.setFileContentMissing(forDirectory: "/work/proj/pkg")
        await mock.setFileContent(FileContent(type: "text", content: "# Root"), forDirectory: "/work/proj")

        await state.loadProjectMemory()

        #expect(state.projectMemory.content == .text("# Root"))
        #expect(state.projectMemory.loadedDirectory == "/work/proj")
    }

    // MARK: - The improve action

    @Test func theImprovePromptKeepsWhatTheUserWrote() {
        #expect(ProjectMemoryPrompt.improve.contains("keep everything the user wrote"))
    }

    @Test func theImprovePromptRejectsGenericAdvice() {
        #expect(ProjectMemoryPrompt.improve.contains("Do not add generic advice"))
    }

    @Test func theRestorePromptCarriesThePreviousContentVerbatim() {
        let previous = "# Old rules\n\n- keep this line\n- and this one"
        let prompt = ProjectMemoryPrompt.restore(previous: previous)
        let body = prompt
            .components(separatedBy: ProjectMemoryPrompt.restoreBegin)
            .last?
            .components(separatedBy: ProjectMemoryPrompt.restoreEnd)
            .first?
            .trimmingCharacters(in: .newlines) ?? ""
        #expect(body == previous)
    }

    @Test @MainActor func improvingSendsThePromptToTheCurrentSession() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.currentSessionID = "s1"

        let sent = await state.improveProjectMemory()

        #expect(sent)
        #expect((await mock.promptAsyncCalls).count == 1)
        #expect((await mock.promptAsyncCalls).first?.0 == "s1")
        #expect((await mock.promptAsyncCalls).first?.1 == ProjectMemoryPrompt.improve)
    }

    @Test @MainActor func improvingIsRefusedWhileTheSessionIsBusy() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.currentSessionID = "s1"
        state.sessionStatuses = ["s1": SessionStatus(type: "busy", attempt: nil, message: nil, next: nil)]

        let sent = await state.improveProjectMemory()

        #expect(!sent)
        #expect((await mock.promptAsyncCalls).isEmpty)
    }

    @Test @MainActor func improvingIsRefusedWithoutASession() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)

        let sent = await state.improveProjectMemory()

        #expect(!sent)
        #expect((await mock.promptAsyncCalls).isEmpty)
    }

    @Test @MainActor func theActionStaysLockedUntilTheTurnSettles() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.currentSessionID = "s1"

        #expect(await state.improveProjectMemory())
        // The request was accepted, but the turn has not started: a second tap must not send
        // the prompt twice.
        #expect(state.projectMemory.pendingAction)
        #expect(!state.canRunProjectMemoryAction)

        state.sessionStatuses = ["s1": SessionStatus(type: "busy", attempt: nil, message: nil, next: nil)]
        state.updateProjectMemoryActionState()
        #expect(state.projectMemory.pendingAction)

        state.sessionStatuses = ["s1": SessionStatus(type: "idle", attempt: nil, message: nil, next: nil)]
        state.updateProjectMemoryActionState()
        #expect(!state.projectMemory.pendingAction)
        #expect(state.canRunProjectMemoryAction)
    }

    @Test @MainActor func aRefusedActionIsNotLeftPending() async {
        let mock = MockAPIClient()
        await mock.setPromptError(APIError.httpError(statusCode: 500, data: Data()))
        let state = makeIsolatedAppState(apiClient: mock)
        state.currentSessionID = "s1"

        #expect(!(await state.improveProjectMemory()))
        #expect(!state.projectMemory.pendingAction)
        #expect(state.canRunProjectMemoryAction)
    }

    @Test @MainActor func restoringSendsTheBaselineBack() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.currentSessionID = "s1"
        state.projectMemory.baseline = ProjectMemorySnapshot(text: "# Old rules")

        let sent = await state.restoreProjectMemory()

        #expect(sent)
        #expect((await mock.promptAsyncCalls).first?.1.contains("# Old rules") == true)
    }

    @Test @MainActor func restoringWithoutABaselineDoesNothing() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.currentSessionID = "s1"

        let sent = await state.restoreProjectMemory()

        #expect(!sent)
        #expect((await mock.promptAsyncCalls).isEmpty)
    }

    @Test @MainActor func restoringAnAbsentBaselineDoesNothing() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.currentSessionID = "s1"
        state.projectMemory.baseline = .absent

        let sent = await state.restoreProjectMemory()

        #expect(!sent)
        #expect((await mock.promptAsyncCalls).isEmpty)
    }

    @Test @MainActor func acceptingTheChangeClearsIt() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.currentSessionID = "s1"
        state.projectMemory.baseline = ProjectMemorySnapshot(text: "# Old")
        state.projectMemory.content = .text("# New")
        #expect(state.projectMemory.hasChange)

        state.acceptProjectMemoryChange()

        #expect(!state.projectMemory.hasChange)
    }

    // MARK: - The write scanner

    @Test func aWriteToTheInstructionFileIsFound() {
        let messages = [assistantMessage(parts: [writePart(path: "AGENTS.md")])]
        #expect(ProjectMemoryChangeScanner.instructionFileWrites(in: messages) == ["p1"])
    }

    @Test func anAbsoluteWriteToTheInstructionFileIsFound() {
        let messages = [assistantMessage(parts: [writePart(path: "/work/proj/AGENTS.md")])]
        #expect(ProjectMemoryChangeScanner.instructionFileWrites(in: messages) == ["p1"])
    }

    @Test func aWriteToAnotherFileIsNotFound() {
        let messages = [assistantMessage(parts: [writePart(path: "src/main.swift")])]
        #expect(ProjectMemoryChangeScanner.instructionFileWrites(in: messages).isEmpty)
    }

    @Test func aReadOfTheInstructionFileIsNotAWrite() {
        let messages = [assistantMessage(parts: [readPart(path: "AGENTS.md")])]
        #expect(ProjectMemoryChangeScanner.instructionFileWrites(in: messages).isEmpty)
    }

    @Test func anEmptyTranscriptHasNoWrite() {
        #expect(ProjectMemoryChangeScanner.instructionFileWrites(in: []).isEmpty)
    }

    // MARK: - Freshness

    @Test @MainActor func aFileThatWasNeverReadIsNotRefreshed() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.messages = [assistantMessage(parts: [writePart(path: "AGENTS.md")])]

        await state.refreshProjectMemoryIfChanged()

        #expect((await mock.fileContentRequests).isEmpty)
    }

    @Test @MainActor func aWriteToTheInstructionFileRefreshesTheContent() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.selectedProjectWorktree = "/work/proj"
        state.currentSessionID = "s1"
        state.sessions = [session(id: "s1", directory: "/work/proj")]
        await mock.setFileContent(result: FileContent(type: "text", content: "# Before"))
        await state.loadProjectMemory()
        #expect(state.projectMemory.content == .text("# Before"))

        state.messages = [assistantMessage(parts: [writePart(path: "AGENTS.md")])]
        await mock.setFileContent(result: FileContent(type: "text", content: "# After"))
        await state.refreshProjectMemoryIfChanged()

        #expect(state.projectMemory.content == .text("# After"))
        #expect(state.projectMemory.hasChange)
    }

    @Test @MainActor func theSameWriteIsNotReadTwice() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.selectedProjectWorktree = "/work/proj"
        state.currentSessionID = "s1"
        state.sessions = [session(id: "s1", directory: "/work/proj")]
        await state.loadProjectMemory()
        state.messages = [assistantMessage(parts: [writePart(path: "AGENTS.md")])]

        await state.refreshProjectMemoryIfChanged()
        let afterFirst = (await mock.fileContentRequests).count
        await state.refreshProjectMemoryIfChanged()

        #expect((await mock.fileContentRequests).count == afterFirst)
    }

    @Test @MainActor func aWriteToAnotherFileDoesNotRefresh() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.selectedProjectWorktree = "/work/proj"
        state.currentSessionID = "s1"
        state.sessions = [session(id: "s1", directory: "/work/proj")]
        await state.loadProjectMemory()
        state.messages = [assistantMessage(parts: [writePart(path: "src/main.swift")])]

        await state.refreshProjectMemoryIfChanged()

        #expect((await mock.fileContentRequests).count == 1)
    }

    // MARK: - Fixtures

    private func session(id: String, directory: String) -> Session {
        Session(
            id: id,
            slug: id,
            projectID: "p1",
            directory: directory,
            parentID: nil,
            title: "Title",
            version: "1",
            time: .init(created: 1, updated: 1, archived: nil),
            share: nil,
            summary: nil
        )
    }

    private func assistantMessage(parts: [Part]) -> MessageWithParts {
        MessageWithParts(
            info: Message(
                id: "m1",
                sessionID: "s1",
                role: "assistant",
                parentID: "u1",
                providerID: nil,
                modelID: nil,
                model: nil,
                error: nil,
                time: Message.TimeInfo(created: 1, completed: 2),
                finish: nil,
                tokens: nil,
                cost: nil,
                structured: nil,
                agent: nil
            ),
            parts: parts
        )
    }

    /// A write tool part whose input names a path.
    private func writePart(path: String) -> Part {
        decodePart("""
        {"id":"p1","messageID":"m1","sessionID":"s1","type":"tool","tool":"write_file","state":{"status":"completed","input":{"path":"\(path)"}}}
        """)
    }

    /// A read tool part whose input names a path.
    private func readPart(path: String) -> Part {
        decodePart("""
        {"id":"p1","messageID":"m1","sessionID":"s1","type":"tool","tool":"read_file","state":{"status":"completed","input":{"path":"\(path)"}}}
        """)
    }

    private func decodePart(_ json: String) -> Part {
        let data = Data(json.utf8)
        do {
            return try JSONDecoder().decode(Part.self, from: data)
        } catch {
            Issue.record("could not decode the fixture part: \(error)")
            return Part(
                id: "p1",
                messageID: "m1",
                sessionID: "s1",
                type: "tool",
                text: nil,
                tool: "write_file",
                callID: nil,
                state: nil,
                metadata: nil,
                files: nil
            )
        }
    }
}
