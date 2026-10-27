import Foundation
import SwiftUI
import Testing
import UIKit
@testable import OpenCodeClient

struct MessageReconciliationTests {
    @Test func orderedIDsMatchServerTimePrefixAndStayMonotonicInOneMillisecond() {
        #expect(OrderedServerID.body(timestamp: 1000, counter: 1).hasPrefix("0000003e8001"))
        #expect(OrderedServerID.body(timestamp: 1000, counter: 2).hasPrefix("0000003e8002"))
        let ids = AppState.makeServerIDs(prefix: "msg", count: 2, timestamp: 1_700_000_000_123)
        #expect(ids.count == 2)
        #expect(ids[0] != ids[1])
        #expect(ids[0] < ids[1])
        #expect(OrderedServerID.isOrdered(ids[0], prefix: "msg"))
        #expect(OrderedServerID.isOrdered(ids[1], prefix: "msg"))
        #expect(!OrderedServerID.isOrdered("msg_" + String(repeating: "a", count: 32), prefix: "msg"))
    }

    @Test func visibleMessagesUsesWindowOrderForLegacyIDsAndOrderedCompareOffWindow() {
        let legacy = [
            row(id: "msg_F", sessionID: "s1", text: "first"),
            row(id: "msg_1", sessionID: "s1", text: "second"),
        ]
        let hiddenByStringOrder = AppState.visibleMessages(legacy, revertMessageID: "msg_1")
        #expect(hiddenByStringOrder.map(\.info.id) == ["msg_F"])

        let offWindowLegacy = AppState.visibleMessages(legacy, revertMessageID: "msg_" + String(repeating: "ab", count: 16))
        #expect(offWindowLegacy.map(\.info.id) == ["msg_F", "msg_1"])

        let ids = AppState.makeServerIDs(prefix: "msg", count: 3, timestamp: 1_700_000_000_200)
        let ordered = [row(id: ids[0], sessionID: "s1", text: "early"), row(id: ids[2], sessionID: "s1", text: "late")]
        let visible = AppState.visibleMessages(ordered, revertMessageID: ids[1])
        #expect(visible.map(\.info.id) == [ids[0]])
    }

    @Test func failedSendMergesSentTextWithPasteAndTypedEditsWithoutDuplicating() {
        let host = HostRequestSnapshot(hostProfileID: UUID(), generation: 1)
        let selection = UUID()
        let pasted = ChatComposerRestore.textAndAttachments(
            sourceSessionID: "a",
            currentSessionID: "a",
            capturedRevision: 3,
            currentRevision: 4,
            capturedHost: host,
            currentHost: host,
            capturedSelection: selection,
            currentSelection: selection,
            sentText: "hello",
            sentAttachments: [],
            currentText: "note",
            currentAttachments: []
        )
        #expect(pasted.text == "hello\nnote")

        let typed = ChatComposerRestore.failedSendText(sentText: "hello", currentText: "typed")
        #expect(typed == "hello\ntyped")
        #expect(ChatComposerRestore.failedSendText(sentText: "hello", currentText: "") == "hello")
        #expect(ChatComposerRestore.failedSendText(sentText: "hello", currentText: "hello\nnote") == "hello\nnote")
        #expect(ChatComposerRestore.failedSendText(sentText: "no", currentText: "note") == "no\nnote")
        #expect(ChatComposerRestore.failedSendText(sentText: "hello", currentText: "hello") == "hello")

        let otherSession = ChatComposerRestore.textAndAttachments(
            sourceSessionID: "a",
            currentSessionID: "b",
            capturedRevision: 3,
            currentRevision: 4,
            capturedHost: host,
            currentHost: host,
            capturedSelection: selection,
            currentSelection: selection,
            sentText: "hello",
            sentAttachments: [],
            currentText: "note",
            currentAttachments: []
        )
        #expect(otherSession.text == "note")

        let otherHost = ChatComposerRestore.textAndAttachments(
            sourceSessionID: "a",
            currentSessionID: "a",
            capturedRevision: 3,
            currentRevision: 4,
            capturedHost: host,
            currentHost: HostRequestSnapshot(hostProfileID: UUID(), generation: 2),
            capturedSelection: selection,
            currentSelection: selection,
            sentText: "hello",
            sentAttachments: [],
            currentText: "note",
            currentAttachments: []
        )
        #expect(otherHost.text == "note")
        #expect(otherHost.attachments.isEmpty)

        let imageA = attachment()
        let imageB = ComposerImageAttachment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            filename: "new.jpg",
            mime: "image/jpeg",
            dataURL: "data:image/jpeg;base64,BBB",
            thumbnailData: Data([0x02]),
            byteSize: 1
        )
        let withImages = ChatComposerRestore.textAndAttachments(
            sourceSessionID: "a",
            currentSessionID: "a",
            capturedRevision: 3,
            currentRevision: 4,
            capturedHost: host,
            currentHost: host,
            capturedSelection: selection,
            currentSelection: selection,
            sentText: "no",
            sentAttachments: [imageA],
            currentText: "note",
            currentAttachments: [imageB]
        )
        #expect(withImages.text == "no\nnote")
        #expect(withImages.attachments.map(\.id) == [imageA.id, imageB.id])

        let otherSessionImages = ChatComposerRestore.textAndAttachments(
            sourceSessionID: "a",
            currentSessionID: "b",
            capturedRevision: 3,
            currentRevision: 4,
            capturedHost: host,
            currentHost: host,
            capturedSelection: selection,
            currentSelection: selection,
            sentText: "no",
            sentAttachments: [imageA],
            currentText: "note",
            currentAttachments: [imageB]
        )
        #expect(otherSessionImages.text == "note")
        #expect(otherSessionImages.attachments.map(\.id) == [imageB.id])
    }

    @Test func composerRestoreStaysOnSourceSessionAndUneditedRevision() {
        let host = HostRequestSnapshot(hostProfileID: UUID(), generation: 1)
        let selection = UUID()
        #expect(ChatComposerRestore.shouldRestore(sourceSessionID: "a", currentSessionID: "a", capturedRevision: 3, currentRevision: 3, capturedHost: host, currentHost: host, capturedSelection: selection, currentSelection: selection))
        #expect(!ChatComposerRestore.shouldRestore(sourceSessionID: "a", currentSessionID: "b", capturedRevision: 3, currentRevision: 3, capturedHost: host, currentHost: host, capturedSelection: selection, currentSelection: selection))
        #expect(!ChatComposerRestore.shouldRestore(sourceSessionID: "a", currentSessionID: "a", capturedRevision: 3, currentRevision: 4, capturedHost: host, currentHost: host, capturedSelection: selection, currentSelection: selection))
        #expect(!ChatComposerRestore.shouldRestore(sourceSessionID: nil, currentSessionID: nil, capturedRevision: 1, currentRevision: 1, capturedHost: host, currentHost: host, capturedSelection: selection, currentSelection: selection))
        #expect(!ChatComposerRestore.shouldRestore(sourceSessionID: "a", currentSessionID: "a", capturedRevision: 3, currentRevision: 3, capturedHost: host, currentHost: HostRequestSnapshot(hostProfileID: host.hostProfileID, generation: 2), capturedSelection: selection, currentSelection: selection))
        #expect(!ChatComposerRestore.shouldRestore(sourceSessionID: "a", currentSessionID: "a", capturedRevision: 3, currentRevision: 3, capturedHost: host, currentHost: host, capturedSelection: selection, currentSelection: UUID()))
    }

    @Test @MainActor func deltaAppendKeepsPartsIndexWithMessageText() {
        let state = makeIsolatedAppState()
        state.currentSessionID = "s1"
        let original = row(id: "m1", sessionID: "s1", text: "Hi")
        state.messages = [original]
        state.partsByMessage = ["m1": original.parts]
        state.messageStore.appendDelta(messageID: "m1", partID: "p-m1", delta: "!")
        #expect(state.messages[0].parts[0].text == "Hi!")
        #expect(state.partsByMessage["m1"]?.first?.text == "Hi!")
    }

    @Test @MainActor func archivedSendKeepsCapturedTargetWhenSelectionStays() async {
        let api = ReconciliationAPI()
        await api.armArchive()
        let state = makeIsolatedAppState(apiClient: api)
        state.currentSessionID = "a"
        state.sessions = [makeSession(id: "a", directory: "/work/a", archived: 10)]
        state.hasServerAgentCatalog = true
        state.agents = [agent("build"), agent("plan")]
        state.selectedAgentName = "build"
        state.modelShortlist = [shortlist("captured"), shortlist("changed")]
        // The model is picked explicitly: the app only writes a model the
        // user chose for this session, never whatever sits at the picker's
        // current index.
        state.setSelectedModelIndex(0)

        let send = Task { await state.sendMessage("continue") }
        await api.waitArchive()
        state.sessions = [makeSession(id: "a", directory: "/work/changed", archived: 10)]
        state.selectedAgentName = "plan"
        state.setSelectedModelIndex(1)
        await api.releaseArchive()
        #expect(await send.value)

        let prompts = await api.prompts
        #expect(prompts.count == 1)
        #expect(prompts[0].sessionID == "a")
        #expect(prompts[0].agent == "")
        #expect(prompts[0].modelID == "captured")
        #expect(prompts[0].directory == "/work/a")
        #expect(state.messages.map(\.info.sessionID) == ["a"])
        #expect(state.messages.first?.parts.contains { $0.text == "continue" } == true)
    }

    @Test @MainActor func archivedSendDoesNotLandOptimisticRowOnTheNewSession() async {
        let api = ReconciliationAPI()
        await api.armArchive()
        let state = makeIsolatedAppState(apiClient: api)
        state.currentSessionID = "a"
        state.sessions = [
            makeSession(id: "a", directory: "/work/a", archived: 10),
            makeSession(id: "b", directory: "/work/b", archived: nil),
        ]
        let attachment = attachment()

        let send = Task { await state.sendMessage("from-a", attachments: [attachment]) }
        await api.waitArchive()
        state.messages = []
        state.partsByMessage = [:]
        state.currentSessionID = "b"
        state.sessionLoadingID = UUID()
        await api.releaseArchive()
        #expect(await send.value == false)
        #expect(await api.prompts.isEmpty)
        #expect(state.messages.isEmpty)
        #expect(state.sessions.first { $0.id == "a" }?.isArchived == false)
        #expect(state.messageStore.outboundRows(hostProfileID: state.currentHostProfileID, sessionID: "b").isEmpty)

        state.currentSessionID = "a"
        await state.loadMessages()
        let restored = state.messages.first { $0.info.sessionID == "a" }
        #expect(restored?.parts.contains { $0.text == "from-a" } == true)
        #expect(restored?.parts.contains { $0.filename == "photo.jpg" } == true)
        #expect(state.messageStore.failedSendReasonsByID[restored?.info.id ?? ""] == L10n.t(.chatSendFailed))
    }

    @Test @MainActor func sessionErrorMarksOnlyThatSessionsOldestPendingSend() async {
        let state = makeIsolatedAppState()
        state.currentSessionID = "a"
        let early = state.appendOptimisticUserMessage("a-text", messageID: "msg_0aaa")
        state.messages = []
        state.partsByMessage = [:]
        state.currentSessionID = "b"
        let later = state.appendOptimisticUserMessage("b-text", messageID: "msg_zzzz")

        await state.applySSEEventForTesting(event("""
        {"payload":{"type":"session.error","properties":{"sessionID":"b","error":{"name":"UnknownError","data":{"message":"boom"}}}}}
        """))

        #expect(state.messageStore.failedSendReasonsByID[early] == nil)
        #expect(state.messageStore.isPendingOptimisticMessage(early))
        #expect(state.messageStore.failedSendReasonsByID[later]?.contains("boom") == true)
        #expect(state.messages.map(\.info.id) == [later])
    }

    @Test @MainActor func failedSendRowReturnsWithItsAttachmentOnTheSourceSession() async throws {
        let api = ReconciliationAPI()
        await api.setPromptError(APIError.invalidURL)
        let state = makeIsolatedAppState(apiClient: api)
        state.currentSessionID = "a"
        state.sessions = [makeSession(id: "a", directory: "/work/a", archived: nil)]
        let sent = await state.sendMessage("keep-me", attachments: [attachment()])
        #expect(!sent)
        let failedID = try #require(state.messages.first?.info.id)
        state.messages = []
        state.partsByMessage = [:]
        state.currentSessionID = "b"
        await state.loadMessages()
        #expect(state.messages.isEmpty)

        state.currentSessionID = "a"
        await state.loadMessages()
        #expect(state.messages.map(\.info.id) == [failedID])
        #expect(state.messages.first?.parts.contains { $0.filename == "photo.jpg" } == true)
        #expect(state.messageStore.failedSendReasonsByID[failedID]?.isEmpty == false)
    }

    @Test @MainActor func staleSnapshotDoesNotRollBackSSEDeleteOrNewerRequest() async {
        let api = ReconciliationAPI()
        await api.armMessages()
        let state = makeIsolatedAppState(apiClient: api)
        state.currentSessionID = "s1"
        state.messages = [row(id: "m1", sessionID: "s1", text: "live")]
        state.sessionStatuses["s1"] = SessionStatus(type: "idle", attempt: nil, message: nil, next: nil)
        state.sessionActivities["s1"] = runningActivity(sessionID: "s1")
        await api.setMessageScripts([
            [row(id: "m1", sessionID: "s1", text: "stale", completed: 130_000), row(id: "stale-only", sessionID: "s1", text: "old")],
            [row(id: "fresh", sessionID: "s1", text: "fresh")],
        ])

        let first = Task { await state.loadMessages() }
        await api.waitMessages(1)
        await state.applySSEEventForTesting(event("""
        {"payload":{"type":"message.removed","properties":{"sessionID":"s1","messageID":"m1"}}}
        """))
        let second = Task { await state.loadMessages() }
        await api.waitMessages(2)
        await api.releaseMessages(1)
        await second.value
        #expect(state.messages.map(\.info.id) == ["fresh"])
        await api.releaseMessages(0)
        await first.value
        #expect(state.messages.map(\.info.id) == ["fresh"])
        #expect(state.sessionActivities["s1"]?.state == .running)
    }

    @Test @MainActor func smallerPageReturningLastDoesNotTruncateTheLargerPage() async {
        let api = ReconciliationAPI()
        await api.armMessages()
        let state = makeIsolatedAppState(apiClient: api)
        state.currentSessionID = "s1"
        let page20 = (1...2).map { row(id: "p\($0)", sessionID: "s1", text: "small") }
        let page40 = (1...4).map { row(id: "p\($0)", sessionID: "s1", text: "large") }
        await api.setMessageScripts([page20, page40])

        let first = Task { await state.loadMessages() }
        await api.waitMessages(1)
        state.loadedMessageLimitBySessionID["s1"] = 40
        let second = Task { await state.loadMessages() }
        await api.waitMessages(2)
        await api.releaseMessages(1)
        await second.value
        #expect(state.messages.count == 4)
        await api.releaseMessages(0)
        await first.value
        #expect(state.messages.map(\.info.id) == page40.map(\.info.id))
        #expect(await api.messageLimits == [20, 40])
        #expect(state.hasMoreHistoryBySessionID["s1"] == false)

        let fullAPI = ReconciliationAPI()
        let fullRows = (1...20).map { row(id: "full-\($0)", sessionID: "s1", text: "page") }
        await fullAPI.setMessageScripts([fullRows])
        let fullState = makeIsolatedAppState(apiClient: fullAPI)
        fullState.currentSessionID = "s1"
        await fullState.loadMessages()
        #expect(await fullAPI.messageLimits == [20])
        #expect(fullState.hasMoreHistoryBySessionID["s1"] == true)
    }

    @Test @MainActor func hostOrSelectionChangeDropsTheSnapshotWithoutRecomputingActivity() async {
        let api = ReconciliationAPI()
        await api.armMessages()
        let state = makeIsolatedAppState(apiClient: api)
        state.currentSessionID = "s1"
        state.sessionStatuses["s1"] = SessionStatus(type: "idle", attempt: nil, message: nil, next: nil)
        state.sessionActivities["s1"] = runningActivity(sessionID: "s1")
        await api.setMessageScripts([[row(id: "done", sessionID: "s1", text: "done", completed: 130_000)]])

        let load = Task { await state.loadMessages() }
        await api.waitMessages(1)
        state.hostRequestGeneration &+= 1
        await api.releaseMessages(0)
        await load.value
        #expect(state.messages.isEmpty)
        #expect(state.sessionActivities["s1"]?.state == .running)

        await api.armMessages()
        await api.setMessageScripts([[row(id: "done", sessionID: "s1", text: "done", completed: 130_000)]])
        state.hostRequestGeneration &-= 1
        let again = Task { await state.loadMessages() }
        await api.waitMessages(1)
        state.sessionLoadingID = UUID()
        await api.releaseMessages(0)
        await again.value
        #expect(state.messages.isEmpty)
        #expect(state.sessionActivities["s1"]?.state == .running)
    }

    @Test @MainActor func acceptedSnapshotStillRecomputesActivity() async {
        let api = ReconciliationAPI()
        await api.setMessageScripts([[row(id: "a1", sessionID: "s1", text: "done", completed: 130_000)]])
        let state = makeIsolatedAppState(apiClient: api)
        state.currentSessionID = "s1"
        state.sessionStatuses["s1"] = SessionStatus(type: "idle", attempt: nil, message: nil, next: nil)
        state.sessionActivities["s1"] = runningActivity(sessionID: "s1")
        await state.loadMessages()
        #expect(state.messages.map(\.info.id) == ["a1"])
        #expect(state.sessionActivities["s1"]?.state == .completed)
        #expect(state.sessionActivities["s1"]?.endedAt?.timeIntervalSince1970 == 130)
    }

    @Test @MainActor func staleLoad404AfterNewerSuccessDoesNotRecover() async {
        let api = ReconciliationAPI()
        await api.armMessages()
        await api.setMessageError(0, notFound())
        await api.setMessageScripts([[], [row(id: "fresh", sessionID: "s1", text: "fresh")]])
        let state = makeIsolatedAppState(apiClient: api)
        state.currentSessionID = "s1"
        state.sessions = [makeSession(id: "s1", directory: "/s", archived: nil)]
        state.sessionActivities["s1"] = runningActivity(sessionID: "s1")

        let first = Task { await state.loadMessages() }
        await api.waitMessages(1)
        let second = Task { await state.loadMessages() }
        await api.waitMessages(2)
        await api.releaseMessages(1)
        await second.value
        await api.releaseMessages(0)
        await first.value

        #expect(state.currentSessionID == "s1")
        #expect(state.messages.map(\.info.id) == ["fresh"])
        #expect(state.sessions.map(\.id) == ["s1"])
        #expect(state.connectionError == nil)
        #expect(state.sessionActivities["s1"]?.state == .running)
    }

    @Test @MainActor func staleLoad404AfterReselectOrHostChangeDoesNotClearWindow() async {
        let api = ReconciliationAPI()
        await api.armMessages()
        await api.setMessageError(0, notFound())
        let state = makeIsolatedAppState(apiClient: api)
        state.currentSessionID = "a"
        state.sessions = [makeSession(id: "a", directory: "/a", archived: nil), makeSession(id: "b", directory: "/b", archived: nil)]
        state.sessionActivities["a"] = runningActivity(sessionID: "a")

        let reselect = Task { await state.loadMessages() }
        await api.waitMessages(1)
        state.currentSessionID = "b"
        state.sessionLoadingID = UUID()
        state.messages = []
        state.currentSessionID = "a"
        state.sessionLoadingID = UUID()
        state.messages = [row(id: "fresh", sessionID: "a", text: "fresh")]
        await api.releaseMessages(0)
        await reselect.value
        #expect(state.currentSessionID == "a")
        #expect(state.messages.map(\.info.id) == ["fresh"])
        #expect(state.connectionError == nil)
        #expect(state.sessionActivities["a"]?.state == .running)

        await api.armMessages()
        await api.setMessageError(0, notFound())
        state.messages = [row(id: "host-window", sessionID: "a", text: "stay")]
        let hostLoad = Task { await state.loadMessages() }
        await api.waitMessages(1)
        state.hostRequestGeneration &+= 1
        await api.releaseMessages(0)
        await hostLoad.value
        #expect(state.currentSessionID == "a")
        #expect(state.messages.map(\.info.id) == ["host-window"])
        #expect(state.connectionError == nil)
    }

    @Test @MainActor func stalePrompt404DoesNotNavigateAwayFromNewWindow() async {
        let api = ReconciliationAPI()
        await api.armPrompt()
        await api.setPromptError(notFound())
        let state = makeIsolatedAppState(apiClient: api)
        state.currentSessionID = "a"
        state.sessions = [makeSession(id: "a", directory: "/a", archived: nil)]
        let host = state.currentHostProfileID

        let reselect = Task { await state.sendMessage("from-a", attachments: [attachment()]) }
        await api.waitPrompt()
        let sourceID = state.messageStore.outboundRows(hostProfileID: host, sessionID: "a").first?.info.id
        state.currentSessionID = "b"
        state.sessionLoadingID = UUID()
        state.messages = []
        state.currentSessionID = "a"
        state.sessionLoadingID = UUID()
        state.messages = [row(id: "fresh", sessionID: "a", text: "fresh")]
        await api.releasePrompt()
        #expect(await reselect.value == false)
        #expect(state.currentSessionID == "a")
        #expect(state.messages.map(\.info.id) == ["fresh"])
        #expect(state.connectionError == nil)
        let reselectSource = state.messageStore.outboundRows(hostProfileID: host, sessionID: "a")
        #expect(reselectSource.count == 1)
        #expect(reselectSource.first?.info.id == sourceID)
        #expect(reselectSource.first?.parts.contains { $0.text == "from-a" } == true)
        #expect(reselectSource.first?.parts.contains { $0.filename == "photo.jpg" } == true)
        #expect(state.messageStore.failedSendReasonsByID[sourceID ?? ""]?.isEmpty == false)

        await api.armPrompt()
        let hostSend = Task { await state.sendMessage("from-host", attachments: [attachment()]) }
        await api.waitPrompt()
        let hostSourceID = state.messageStore.outboundRows(hostProfileID: host, sessionID: "a").last?.info.id
        state.hostRequestGeneration &+= 1
        state.currentHostProfileID = UUID()
        state.sessionLoadingID = UUID()
        state.messages = [row(id: "new-host", sessionID: "a", text: "new-host")]
        await api.releasePrompt()
        #expect(await hostSend.value == false)
        #expect(state.messages.map(\.info.id) == ["new-host"])
        #expect(await api.prompts.count == 2)
        let hostSource = state.messageStore.outboundRows(hostProfileID: host, sessionID: "a")
        #expect(hostSource.contains { $0.info.id == hostSourceID && $0.parts.contains { $0.text == "from-host" } })
        #expect(state.messageStore.failedSendReasonsByID[hostSourceID ?? ""]?.isEmpty == false)
        #expect(state.messageStore.outboundRows(hostProfileID: state.currentHostProfileID, sessionID: "a").isEmpty)
    }

    @Test @MainActor func archivedChildRestoreStopsAtHostBoundary() async {
        let api = ReconciliationAPI()
        await api.armArchive()
        let state = makeIsolatedAppState(apiClient: api)
        state.currentSessionID = "a"
        state.sessions = [
            makeSession(id: "a", directory: "/work/a", archived: 10),
            makeSession(id: "c", directory: "/work/a", archived: 10, parentID: "a"),
        ]
        let oldHost = state.currentHostProfileID
        let send = Task { await state.sendMessage("from-a", attachments: [attachment()]) }
        await api.waitArchive(1)
        state.hostRequestGeneration &+= 1
        state.currentHostProfileID = UUID()
        state.sessions = [makeSession(id: "new", directory: "/new", archived: nil)]
        state.currentSessionID = "new"
        state.sessionLoadingID = UUID()
        state.messages = [row(id: "new-row", sessionID: "new", text: "stay")]
        await api.releaseArchive(0)
        #expect(await send.value == false)
        #expect(await api.archiveSessionIDs == ["a"])
        #expect(await api.prompts.isEmpty)
        #expect(state.sessions.map(\.id) == ["new"])
        #expect(state.messages.map(\.info.id) == ["new-row"])
        let source = state.messageStore.outboundRows(hostProfileID: oldHost, sessionID: "a")
        #expect(source.first?.parts.contains { $0.text == "from-a" } == true)
        #expect(source.first?.parts.contains { $0.filename == "photo.jpg" } == true)
        #expect(state.messageStore.outboundRows(hostProfileID: state.currentHostProfileID, sessionID: "a").isEmpty)
    }

    @Test @MainActor func sameHostSessionSwitchStillRestoresEntitiesWithoutPrompt() async {
        let api = ReconciliationAPI()
        await api.armArchive()
        let state = makeIsolatedAppState(apiClient: api)
        state.currentSessionID = "a"
        state.sessions = [
            makeSession(id: "a", directory: "/work/a", archived: 10),
            makeSession(id: "c", directory: "/work/a", archived: 10, parentID: "a"),
            makeSession(id: "b", directory: "/work/b", archived: nil),
        ]
        let send = Task { await state.sendMessage("from-a", attachments: [attachment()]) }
        await api.waitArchive(1)
        state.currentSessionID = "b"
        state.sessionLoadingID = UUID()
        state.messages = []
        await api.releaseArchive(0)
        await api.waitArchive(2)
        await api.releaseArchive(1)
        #expect(await send.value == false)
        #expect(await api.archiveSessionIDs == ["a", "c"])
        #expect(await api.prompts.isEmpty)
        #expect(state.sessions.first { $0.id == "a" }?.isArchived == false)
        #expect(state.sessions.first { $0.id == "c" }?.isArchived == false)
        #expect(state.messages.isEmpty)
        #expect(state.messageStore.outboundRows(hostProfileID: state.currentHostProfileID, sessionID: "b").isEmpty)
        let source = state.messageStore.outboundRows(hostProfileID: state.currentHostProfileID, sessionID: "a")
        #expect(source.first?.parts.contains { $0.text == "from-a" } == true)
    }

    @Test @MainActor func offscreenErrorAckAndRemoveKeepSourceRecordsOnly() async {
        let api = ReconciliationAPI()
        let state = makeIsolatedAppState(apiClient: api)
        let host = state.currentHostProfileID
        state.currentSessionID = "a"
        let pendingID = state.appendOptimisticUserMessage("a-text", attachments: [attachment()], messageID: "msg_a", sessionID: "a")
        state.currentSessionID = "b"
        state.messages = [row(id: "b1", sessionID: "b", text: "visible")]
        state.partsByMessage = ["b1": state.messages[0].parts]
        let revision = state.messageStore.liveRevision

        await state.applySSEEventForTesting(event("""
        {"payload":{"type":"session.error","properties":{"sessionID":"a","error":{"name":"UnknownError","data":{"message":"boom"}}}}}
        """))
        #expect(await api.messageLimits.isEmpty)
        #expect(state.messages.map(\.info.id) == ["b1"])
        #expect(state.messageStore.liveRevision == revision)
        #expect(state.messageStore.failedSendReasonsByID[pendingID]?.contains("boom") == true)
        #expect(!state.messageStore.isPendingOptimisticMessage(pendingID))
        let failed = state.messageStore.outboundRows(hostProfileID: host, sessionID: "a")
        #expect(failed.first?.parts.contains { $0.text == "a-text" } == true)
        #expect(failed.first?.parts.contains { $0.filename == "photo.jpg" } == true)

        let ackID = state.appendOptimisticUserMessage("ack-me", messageID: "msg_ack", sessionID: "a")
        await state.applySSEEventForTesting(event("""
        {"payload":{"type":"message.updated","properties":{"sessionID":"a","info":{"id":"\(ackID)","role":"user","sessionID":"a","time":{"created":1}}}}}
        """))
        #expect(state.messages.map(\.info.id) == ["b1"])
        #expect(state.messageStore.liveRevision == revision)
        #expect(!state.messageStore.isPendingOptimisticMessage(ackID))
        #expect(state.messageStore.outboundRows(hostProfileID: host, sessionID: "a").contains { $0.info.id == ackID } == false)
        state.currentSessionID = "a"
        state.messages = []
        await state.loadMessages()
        #expect(state.messages.contains { $0.info.id == ackID } == false)
        #expect(state.messages.contains { $0.info.id == pendingID })

        state.currentSessionID = "b"
        state.messages = [row(id: "b1", sessionID: "b", text: "visible")]
        let removedID = state.appendOptimisticUserMessage("remove-me", messageID: "msg_remove", sessionID: "a")
        let revisionAfterLoad = state.messageStore.liveRevision
        await state.applySSEEventForTesting(event("""
        {"payload":{"type":"message.removed","properties":{"sessionID":"a","messageID":"\(removedID)"}}}
        """))
        #expect(state.messages.map(\.info.id) == ["b1"])
        #expect(state.messageStore.liveRevision == revisionAfterLoad)
        #expect(state.messageStore.outboundRows(hostProfileID: host, sessionID: "a").contains { $0.info.id == removedID } == false)
        state.currentSessionID = "a"
        state.messages = []
        await state.loadMessages()
        #expect(state.messages.contains { $0.info.id == removedID } == false)
    }

    @Test @MainActor func confirmedDeletionClearsOutboundButWindowClearDoesNot() async throws {
        let state = makeIsolatedAppState()
        let host = state.currentHostProfileID
        state.currentSessionID = "a"
        let aID = state.appendOptimisticUserMessage("a-text", attachments: [attachment()], messageID: "msg_a", sessionID: "a")
        let bID = state.appendOptimisticUserMessage("b-text", messageID: "msg_b", sessionID: "b")
        state.clearCurrentSessionViewState()
        #expect(state.messages.isEmpty)
        #expect(state.messageStore.outboundRows(hostProfileID: host, sessionID: "a").map(\.info.id) == [aID])
        state.resetConnectionRuntimeForHostSwitch()
        #expect(state.messageStore.outboundRows(hostProfileID: host, sessionID: "a").map(\.info.id) == [aID])
        #expect(state.messageStore.outboundRows(hostProfileID: host, sessionID: "b").map(\.info.id) == [bID])

        state.noteConfirmedMissingSession("a", hostProfileID: host, clearSelection: false)
        #expect(state.messageStore.outboundRows(hostProfileID: host, sessionID: "a").isEmpty)
        #expect(state.messageStore.failedSendReasonsByID[aID] == nil)
        #expect(!state.messageStore.isPendingOptimisticMessage(aID))
        #expect(state.messageStore.outboundRows(hostProfileID: host, sessionID: "b").map(\.info.id) == [bID])
        state.messageStore.markSendFailed(messageID: aID, reason: "late")
        await state.applySSEEventForTesting(event("""
        {"payload":{"type":"session.error","properties":{"sessionID":"a","error":{"name":"UnknownError","data":{"message":"late"}}}}}
        """))
        #expect(state.messageStore.failedSendReasonsByID[aID] == nil)
        #expect(state.messageStore.outboundRows(hostProfileID: host, sessionID: "a").isEmpty)

        var other = HostProfile.defaultProfile(serverURL: "http://127.0.0.1:9")
        other.name = "Other"
        state.hostProfiles.append(other)
        _ = state.appendOptimisticUserMessage("other-text", messageID: "msg_other", sessionID: "s", hostProfileID: other.id)
        try state.deleteHostProfile(other)
        #expect(state.messageStore.outboundRows(hostProfileID: other.id, sessionID: "s").isEmpty)
        #expect(state.messageStore.failedSendReasonsByID["msg_other"] == nil)
        #expect(state.messageStore.outboundRows(hostProfileID: host, sessionID: "b").map(\.info.id) == [bID])

        let otherHost = UUID()
        let sameSessionPending = state.appendOptimisticUserMessage("other-pending", attachments: [attachment()], messageID: "msg_other_pending", sessionID: "a", hostProfileID: otherHost)
        let sameSessionFailed = state.appendOptimisticUserMessage("other-failed", attachments: [attachment()], messageID: "msg_other_failed", sessionID: "a", hostProfileID: otherHost)
        state.messageStore.markSendFailed(messageID: sameSessionFailed, reason: "kept-failure")
        let currentOnly = state.appendOptimisticUserMessage("current-only", attachments: [attachment()], messageID: "msg_current_only", sessionID: "a", hostProfileID: host)
        state.noteConfirmedMissingSession("a", hostProfileID: host, clearSelection: false)
        #expect(state.messageStore.outboundRows(hostProfileID: host, sessionID: "a").isEmpty)
        #expect(state.messageStore.failedSendReasonsByID[currentOnly] == nil)
        #expect(!state.messageStore.isPendingOptimisticMessage(currentOnly))
        let otherRows = state.messageStore.outboundRows(hostProfileID: otherHost, sessionID: "a")
        #expect(otherRows.contains { $0.info.id == sameSessionPending && $0.parts.contains { $0.text == "other-pending" && $0.filename == nil } && $0.parts.contains { $0.filename == "photo.jpg" } })
        #expect(otherRows.contains { $0.info.id == sameSessionFailed && $0.parts.contains { $0.text == "other-failed" } && $0.parts.contains { $0.filename == "photo.jpg" } })
        #expect(state.messageStore.isPendingOptimisticMessage(sameSessionPending))
        #expect(state.messageStore.failedSendReasonsByID[sameSessionFailed] == "kept-failure")

        state.currentHostProfileID = otherHost
        await state.applySSEEventForTesting(event("""
        {"payload":{"type":"session.deleted","properties":{"sessionID":"a"}}}
        """))
        #expect(state.messageStore.outboundRows(hostProfileID: otherHost, sessionID: "a").isEmpty)
        #expect(state.messageStore.failedSendReasonsByID[sameSessionFailed] == nil)
        #expect(!state.messageStore.isPendingOptimisticMessage(sameSessionPending))
        #expect(state.messageStore.outboundRows(hostProfileID: host, sessionID: "b").map(\.info.id) == [bID])
    }

    @Test @MainActor func deleteSessionCapturesSourceHostAcrossAwait() async throws {
        let api = ReconciliationAPI()
        await api.armDelete()
        let state = makeIsolatedAppState(apiClient: api)
        let sourceHost = state.currentHostProfileID
        let otherHost = UUID()
        state.currentSessionID = "a"
        state.sessions = [
            makeSession(id: "a", directory: "/work/a", archived: nil),
            makeSession(id: "b", directory: "/work/b", archived: nil),
        ]
        let sourceID = state.appendOptimisticUserMessage("source-text", attachments: [attachment()], messageID: "msg_src", sessionID: "a")
        let otherPending = state.appendOptimisticUserMessage("other-pending", attachments: [attachment()], messageID: "msg_other_pending", sessionID: "a", hostProfileID: otherHost)
        let otherFailed = state.appendOptimisticUserMessage("other-failed", attachments: [attachment()], messageID: "msg_other_failed", sessionID: "a", hostProfileID: otherHost)
        state.messageStore.markSendFailed(messageID: otherFailed, reason: "kept-failure")

        let deleting = Task { try await state.deleteSession(sessionID: "a") }
        await api.waitDelete()
        state.currentHostProfileID = otherHost
        state.hostRequestGeneration &+= 1
        let h2A = makeSession(id: "a", directory: "/h2/a", archived: nil)
        let h2B = makeSession(id: "b", directory: "/h2/b", archived: nil)
        state.sessions = [h2A, h2B]
        state.currentSessionID = "a"
        let h2Window = row(id: "h2m", sessionID: "a", text: "h2-window")
        state.messages = [h2Window]
        state.partsByMessage = ["h2m": h2Window.parts]
        state.messageStore.recordPartType(sessionID: "a", partID: "p-h2m", type: "text")
        state.messageStore.recordPartType(sessionID: "b", partID: "p-h2b", type: "tool")
        let h2Todo = TodoItem(content: "h2-todo", status: "pending", priority: "high", id: "todo-h2")
        let h2OtherTodo = TodoItem(content: "h2-b", status: "pending", priority: "low", id: "todo-b")
        state.sessionTodos = ["a": [h2Todo], "b": [h2OtherTodo]]
        let h2Status = SessionStatus(type: "busy", attempt: 2, message: "h2", next: 9)
        let h2OtherStatus = SessionStatus(type: "idle", attempt: nil, message: nil, next: nil)
        state.sessionStatuses = ["a": h2Status, "b": h2OtherStatus]
        state.loadedMessageLimitBySessionID = ["a": 40, "b": 20]
        state.hasMoreHistoryBySessionID = ["a": true, "b": false]
        state.sessionActivities["a"] = runningActivity(sessionID: "a")
        let selectionToken = state.sessionLoadingID
        await api.releaseDelete()
        try await deleting.value

        #expect(state.messageStore.outboundRows(hostProfileID: sourceHost, sessionID: "a").isEmpty)
        #expect(state.messageStore.failedSendReasonsByID[sourceID] == nil)
        #expect(!state.messageStore.isPendingOptimisticMessage(sourceID))
        let kept = state.messageStore.outboundRows(hostProfileID: otherHost, sessionID: "a")
        #expect(kept.contains { $0.info.id == otherPending && $0.parts.contains { $0.text == "other-pending" } && $0.parts.contains { $0.filename == "photo.jpg" } })
        #expect(kept.contains { $0.info.id == otherFailed && $0.parts.contains { $0.text == "other-failed" } && $0.parts.contains { $0.filename == "photo.jpg" } })
        #expect(state.messageStore.isPendingOptimisticMessage(otherPending))
        #expect(state.messageStore.failedSendReasonsByID[otherFailed] == "kept-failure")
        #expect(state.sessions == [h2A, h2B])
        #expect(state.currentSessionID == "a")
        #expect(state.sessionLoadingID == selectionToken)
        #expect(state.messages.map(\.info.id) == ["h2m"])
        #expect(state.messages.first?.parts.first?.text == "h2-window")
        #expect(state.partsByMessage["h2m"]?.first?.text == "h2-window")
        #expect(state.messageStore.partType(for: "p-h2m", inSession: "a") == "text")
        #expect(state.messageStore.partType(for: "p-h2b", inSession: "b") == "tool")
        #expect(state.sessionTodos["a"] == [h2Todo])
        #expect(state.sessionTodos["b"] == [h2OtherTodo])
        #expect(state.sessionStatuses["a"] == h2Status)
        #expect(state.sessionStatuses["b"] == h2OtherStatus)
        #expect(state.loadedMessageLimitBySessionID == ["a": 40, "b": 20])
        #expect(state.hasMoreHistoryBySessionID == ["a": true, "b": false])
        #expect(state.sessionActivities["a"]?.state == .running)
        #expect(state.sessionActivities["a"]?.text == "Running")
        #expect(!state.sessionScope.confirmedMissingSessionIDs.contains("a"))
    }

    @Test @MainActor func singleRequestDropsSnapshotAfterSSEDelete() async {
        let api = ReconciliationAPI()
        await api.armMessages()
        await api.setMessageScripts([[
            row(id: "m1", sessionID: "s1", text: "stale"),
            row(id: "stale-only", sessionID: "s1", text: "old"),
        ]])
        let state = makeIsolatedAppState(apiClient: api)
        state.currentSessionID = "s1"
        state.messages = [row(id: "m1", sessionID: "s1", text: "live")]
        state.sessionActivities["s1"] = runningActivity(sessionID: "s1")
        state.sessionStatuses["s1"] = SessionStatus(type: "idle", attempt: nil, message: nil, next: nil)

        let load = Task { await state.loadMessages() }
        await api.waitMessages(1)
        await state.applySSEEventForTesting(event("""
        {"payload":{"type":"message.removed","properties":{"sessionID":"s1","messageID":"m1"}}}
        """))
        await api.releaseMessages(0)
        await load.value
        #expect(state.messageSnapshotRequestSequence == 1)
        #expect(state.acceptedMessageSnapshotSequence == 0)
        #expect(state.messages.map(\.info.id).contains("stale-only") == false)
        #expect(state.messages.map(\.info.id).contains("m1") == false)
        #expect(state.sessionActivities["s1"]?.state == .running)
    }

    @Test @MainActor func singleRequestDropsSnapshotAfterSSEUpsertAndDelta() async {
        let deltaAPI = ReconciliationAPI()
        await deltaAPI.armMessages()
        await deltaAPI.setMessageScripts([[
            row(id: "m1", sessionID: "s1", text: "stale"),
            row(id: "stale-only", sessionID: "s1", text: "old"),
        ]])
        let deltaState = makeIsolatedAppState(apiClient: deltaAPI)
        deltaState.currentSessionID = "s1"
        let original = row(id: "m1", sessionID: "s1", text: "live")
        deltaState.messages = [original]
        deltaState.partsByMessage = ["m1": original.parts]
        deltaState.messageStore.recordPartType(sessionID: "s1", partID: "p-m1", type: "text")
        deltaState.sessionActivities["s1"] = runningActivity(sessionID: "s1")
        deltaState.sessionStatuses["s1"] = SessionStatus(type: "idle", attempt: nil, message: nil, next: nil)

        let deltaLoad = Task { await deltaState.loadMessages() }
        await deltaAPI.waitMessages(1)
        await deltaState.applySSEEventForTesting(event("""
        {"payload":{"type":"message.part.delta","properties":{"sessionID":"s1","messageID":"m1","partID":"p-m1","field":"text","delta":"!"}}}
        """))
        await deltaAPI.releaseMessages(0)
        await deltaLoad.value
        #expect(deltaState.messageSnapshotRequestSequence == 1)
        #expect(deltaState.acceptedMessageSnapshotSequence == 0)
        #expect(deltaState.messages.contains { $0.info.id == "m1" && $0.parts.first?.text == "live!" })
        #expect(deltaState.partsByMessage["m1"]?.first?.text == "live!")
        #expect(deltaState.messages.contains { $0.info.id == "stale-only" } == false)
        #expect(deltaState.sessionActivities["s1"]?.state == .running)

        let upsertAPI = ReconciliationAPI()
        await upsertAPI.armMessages()
        await upsertAPI.setMessageScripts([[
            row(id: "m1", sessionID: "s1", text: "stale"),
            row(id: "stale-only", sessionID: "s1", text: "old"),
        ]])
        let upsertState = makeIsolatedAppState(apiClient: upsertAPI)
        upsertState.currentSessionID = "s1"
        let upsertOriginal = row(id: "m1", sessionID: "s1", text: "live")
        upsertState.messages = [upsertOriginal]
        upsertState.partsByMessage = ["m1": upsertOriginal.parts]
        upsertState.sessionActivities["s1"] = runningActivity(sessionID: "s1")
        upsertState.sessionStatuses["s1"] = SessionStatus(type: "idle", attempt: nil, message: nil, next: nil)

        let upsertLoad = Task { await upsertState.loadMessages() }
        await upsertAPI.waitMessages(1)
        await upsertState.applySSEEventForTesting(event("""
        {"payload":{"type":"message.updated","properties":{"sessionID":"s1","info":{"id":"sse-new","sessionID":"s1","role":"assistant","time":{"created":1000}}}}}
        """))
        await upsertAPI.releaseMessages(0)
        await upsertLoad.value
        #expect(upsertState.messageSnapshotRequestSequence == 1)
        #expect(upsertState.acceptedMessageSnapshotSequence == 0)
        #expect(upsertState.messages.contains { $0.info.id == "sse-new" })
        #expect(upsertState.messages.contains { $0.info.id == "stale-only" } == false)
        #expect(upsertState.sessionActivities["s1"]?.state == .running)
    }

    @Test @MainActor func composerBindingRestoresUneditedInputAndKeepsEditedInput() async {
        let unedited = await composerFailureHarness()
        var text = "keep-me"
        var revision: UInt64 = 4
        var attachments = [attachment()]
        let captured = revision
        let sentText = text
        let sentAttachments = attachments
        let uneditedHost = unedited.state.captureHostRequestSnapshot()
        let uneditedSelection = unedited.state.sessionLoadingID
        text = ""
        attachments = []
        let uneditedSend = Task { await unedited.state.sendMessage(sentText, attachments: sentAttachments) }
        await unedited.api.waitPrompt()
        await unedited.api.releasePrompt()
        #expect(await uneditedSend.value == false)
        let restored = ChatComposerRestore.textAndAttachments(
            sourceSessionID: "a",
            currentSessionID: unedited.state.currentSessionID,
            capturedRevision: captured,
            currentRevision: revision,
            capturedHost: uneditedHost,
            currentHost: unedited.state.captureHostRequestSnapshot(),
            capturedSelection: uneditedSelection,
            currentSelection: unedited.state.sessionLoadingID,
            sentText: sentText,
            sentAttachments: sentAttachments,
            currentText: text,
            currentAttachments: attachments
        )
        text = restored.text
        attachments = restored.attachments
        #expect(text == "keep-me")
        #expect(attachments.first?.filename == "photo.jpg")
        #expect(revision == captured)
        let uneditedSource = unedited.state.messageStore.outboundRows(hostProfileID: unedited.state.currentHostProfileID, sessionID: "a")
        #expect(uneditedSource.first?.parts.contains { $0.text == "keep-me" } == true)
        #expect(uneditedSource.first?.parts.contains { $0.filename == "photo.jpg" } == true)

        let edited = await composerFailureHarness()
        text = "keep-me"
        revision = 4
        attachments = [attachment()]
        let editedCaptured = revision
        let editedSent = text
        let editedAttachments = attachments
        let editedHost = edited.state.captureHostRequestSnapshot()
        let editedSelection = edited.state.sessionLoadingID
        let binding = ChatComposerInputBinding.make(
            text: { text },
            setText: { text = $0 },
            revision: { revision },
            setRevision: { revision = $0 }
        )
        text = ""
        attachments = []
        let editedSend = Task { await edited.state.sendMessage(editedSent, attachments: editedAttachments) }
        await edited.api.waitPrompt()
        let textView = UITextView()
        textView.text = "typed-after-send"
        let coordinator = ChatComposerTextView.Coordinator(
            text: binding,
            hasMarkedText: .constant(false),
            contentHeight: .constant(DesignControls.composerTextMinHeight),
            onSubmit: {}
        )
        coordinator.textViewDidChange(textView)
        #expect(revision == editedCaptured &+ 1)
        #expect(text == "typed-after-send")
        await edited.api.releasePrompt()
        #expect(await editedSend.value == false)
        let kept = ChatComposerRestore.textAndAttachments(
            sourceSessionID: "a",
            currentSessionID: edited.state.currentSessionID,
            capturedRevision: editedCaptured,
            currentRevision: revision,
            capturedHost: editedHost,
            currentHost: edited.state.captureHostRequestSnapshot(),
            capturedSelection: editedSelection,
            currentSelection: edited.state.sessionLoadingID,
            sentText: editedSent,
            sentAttachments: editedAttachments,
            currentText: text,
            currentAttachments: attachments
        )
        #expect(kept.text == "keep-me\ntyped-after-send")
        #expect(kept.attachments.map(\.id) == editedAttachments.map(\.id))
        let editedSource = edited.state.messageStore.outboundRows(hostProfileID: edited.state.currentHostProfileID, sessionID: "a")
        #expect(editedSource.first?.parts.contains { $0.text == "keep-me" } == true)
        #expect(editedSource.first?.parts.contains { $0.filename == "photo.jpg" } == true)
    }

    @Test @MainActor func composerBindingKeepsOtherSessionDraftAndSourceFailure() async {
        let harness = await composerFailureHarness()
        var text = "from-a"
        var revision: UInt64 = 2
        var attachments = [attachment()]
        let captured = revision
        let sentText = text
        let sentAttachments = attachments
        let capturedHost = harness.state.captureHostRequestSnapshot()
        let capturedSelection = harness.state.sessionLoadingID
        text = ""
        attachments = []
        let send = Task { await harness.state.sendMessage(sentText, attachments: sentAttachments) }
        await harness.api.waitPrompt()
        harness.state.currentSessionID = "b"
        harness.state.sessionLoadingID = UUID()
        revision &+= 1
        text = "b-draft"
        attachments = []
        await harness.api.releasePrompt()
        #expect(await send.value == false)
        let restored = ChatComposerRestore.textAndAttachments(
            sourceSessionID: "a",
            currentSessionID: harness.state.currentSessionID,
            capturedRevision: captured,
            currentRevision: revision,
            capturedHost: capturedHost,
            currentHost: harness.state.captureHostRequestSnapshot(),
            capturedSelection: capturedSelection,
            currentSelection: harness.state.sessionLoadingID,
            sentText: sentText,
            sentAttachments: sentAttachments,
            currentText: text,
            currentAttachments: attachments
        )
        #expect(restored.text == "b-draft")
        #expect(restored.attachments.isEmpty)
        #expect(harness.state.currentSessionID == "b")
        let source = harness.state.messageStore.outboundRows(hostProfileID: harness.state.currentHostProfileID, sessionID: "a")
        #expect(source.first?.parts.contains { $0.text == "from-a" } == true)
        #expect(source.first?.parts.contains { $0.filename == "photo.jpg" } == true)
        #expect(harness.state.messageStore.failedSendReasonsByID[source.first?.info.id ?? ""]?.isEmpty == false)
    }

    @Test @MainActor func composerReselectAndHostGenerationDoNotRefillBeforeOnChange() async throws {
        let harness = await composerFailureHarness()
        harness.state.sessions.append(makeSession(id: "b", directory: "/work/b", archived: nil))
        var text = "from-a"
        var revision: UInt64 = 2
        var attachments = [attachment()]
        let capturedRevision = revision
        let capturedHost = harness.state.captureHostRequestSnapshot()
        let capturedSelection = harness.state.sessionLoadingID
        let sentText = text
        let sentAttachments = attachments
        text = ""
        attachments = []
        let send = Task { await harness.state.sendMessage(sentText, attachments: sentAttachments) }
        await harness.api.waitPrompt()
        let sessionB = try #require(harness.state.sessions.first { $0.id == "b" })
        let sessionA = try #require(harness.state.sessions.first { $0.id == "a" })
        harness.state.selectSession(sessionB)
        harness.state.selectSession(sessionA)
        #expect(revision == capturedRevision)
        #expect(harness.state.currentSessionID == "a")
        #expect(harness.state.sessionLoadingID != capturedSelection)
        await harness.api.releasePrompt()
        #expect(await send.value == false)
        let restored = ChatComposerRestore.textAndAttachments(
            sourceSessionID: "a",
            currentSessionID: harness.state.currentSessionID,
            capturedRevision: capturedRevision,
            currentRevision: revision,
            capturedHost: capturedHost,
            currentHost: harness.state.captureHostRequestSnapshot(),
            capturedSelection: capturedSelection,
            currentSelection: harness.state.sessionLoadingID,
            sentText: sentText,
            sentAttachments: sentAttachments,
            currentText: text,
            currentAttachments: attachments
        )
        #expect(restored.text.isEmpty)
        #expect(restored.attachments.isEmpty)
        let source = harness.state.messageStore.outboundRows(hostProfileID: capturedHost.hostProfileID, sessionID: "a")
        #expect(source.first?.parts.contains { $0.text == "from-a" } == true)
        #expect(source.first?.parts.contains { $0.filename == "photo.jpg" } == true)
        #expect(harness.state.messageStore.failedSendReasonsByID[source.first?.info.id ?? ""]?.isEmpty == false)

        let hostHarness = await composerFailureHarness()
        var hostText = "from-a"
        var hostRevision: UInt64 = 2
        var hostAttachments = [attachment()]
        let hostCapturedRevision = hostRevision
        let hostCaptured = hostHarness.state.captureHostRequestSnapshot()
        let hostSelection = hostHarness.state.sessionLoadingID
        let hostSent = hostText
        let hostSentAttachments = hostAttachments
        hostText = ""
        hostAttachments = []
        let hostSend = Task { await hostHarness.state.sendMessage(hostSent, attachments: hostSentAttachments) }
        await hostHarness.api.waitPrompt()
        hostHarness.state.hostRequestGeneration &+= 1
        hostHarness.state.currentHostProfileID = UUID()
        #expect(hostHarness.state.currentSessionID == "a")
        #expect(hostRevision == hostCapturedRevision)
        #expect(hostHarness.state.sessionLoadingID == hostSelection)
        await hostHarness.api.releasePrompt()
        #expect(await hostSend.value == false)
        let hostRestored = ChatComposerRestore.textAndAttachments(
            sourceSessionID: "a",
            currentSessionID: hostHarness.state.currentSessionID,
            capturedRevision: hostCapturedRevision,
            currentRevision: hostRevision,
            capturedHost: hostCaptured,
            currentHost: hostHarness.state.captureHostRequestSnapshot(),
            capturedSelection: hostSelection,
            currentSelection: hostHarness.state.sessionLoadingID,
            sentText: hostSent,
            sentAttachments: hostSentAttachments,
            currentText: hostText,
            currentAttachments: hostAttachments
        )
        #expect(hostRestored.text.isEmpty)
        #expect(hostRestored.attachments.isEmpty)
        let hostSource = hostHarness.state.messageStore.outboundRows(hostProfileID: hostCaptured.hostProfileID, sessionID: "a")
        #expect(hostSource.first?.parts.contains { $0.text == "from-a" } == true)
        #expect(hostSource.first?.parts.contains { $0.filename == "photo.jpg" } == true)
        #expect(hostHarness.state.messageStore.failedSendReasonsByID[hostSource.first?.info.id ?? ""]?.isEmpty == false)
    }

    @Test @MainActor func restoreGateDeletionDoesNotReviveSourceOrChild() async throws {
        let profileAPI = ReconciliationAPI()
        await profileAPI.armArchive()
        let profileState = makeIsolatedAppState(apiClient: profileAPI)
        let sourceHost = profileState.currentHostProfileID
        var other = HostProfile.defaultProfile(serverURL: "http://127.0.0.1:9")
        other.name = "Other"
        profileState.hostProfiles.append(other)
        profileState.currentSessionID = "a"
        profileState.sessions = [
            makeSession(id: "a", directory: "/work/a", archived: 10),
            makeSession(id: "c", directory: "/work/a", archived: 10, parentID: "a"),
        ]
        let profileSend = Task { await profileState.sendMessage("from-a", attachments: [attachment()]) }
        await profileAPI.waitArchive(1)
        let sourceID = profileState.messageStore.outboundRows(hostProfileID: sourceHost, sessionID: "a").first?.info.id
        #expect(sourceID != nil)
        let currentProfile = try #require(profileState.hostProfiles.first { $0.id == sourceHost })
        try profileState.deleteHostProfile(currentProfile)
        await profileAPI.releaseArchive(0)
        await profileAPI.releaseArchive(1)
        #expect(await profileSend.value == false)
        #expect(await profileAPI.archiveSessionIDs == ["a"])
        #expect(await profileAPI.prompts.isEmpty)
        #expect(profileState.sessions.contains { $0.id == "a" } == false)
        #expect(profileState.sessions.contains { $0.id == "c" } == false)
        #expect(profileState.messageStore.outboundRows(hostProfileID: sourceHost, sessionID: "a").isEmpty)
        #expect(profileState.messageStore.failedSendReasonsByID[sourceID ?? ""] == nil)
        #expect(!profileState.messageStore.isPendingOptimisticMessage(sourceID ?? ""))
        #expect(profileState.messageStore.failedSendReasonsByID.isEmpty)

        let sessionAPI = ReconciliationAPI()
        await sessionAPI.armArchive()
        let sessionState = makeIsolatedAppState(apiClient: sessionAPI)
        let sessionHost = sessionState.currentHostProfileID
        sessionState.currentSessionID = "a"
        sessionState.sessions = [
            makeSession(id: "a", directory: "/work/a", archived: 10),
            makeSession(id: "c", directory: "/work/a", archived: 10, parentID: "a"),
            makeSession(id: "b", directory: "/work/b", archived: nil),
        ]
        let sessionSend = Task { await sessionState.sendMessage("from-a", attachments: [attachment()]) }
        await sessionAPI.waitArchive(1)
        let deletedSourceID = sessionState.messageStore.outboundRows(hostProfileID: sessionHost, sessionID: "a").first?.info.id
        #expect(deletedSourceID != nil)
        sessionState.noteConfirmedMissingSession("a", hostProfileID: sessionHost, clearSelection: true)
        await sessionAPI.releaseArchive(0)
        await sessionAPI.releaseArchive(1)
        #expect(await sessionSend.value == false)
        #expect(await sessionAPI.archiveSessionIDs == ["a"])
        #expect(await sessionAPI.prompts.isEmpty)
        #expect(sessionState.sessions.contains { $0.id == "a" } == false)
        #expect(sessionState.sessions.first { $0.id == "c" }?.isArchived == true)
        #expect(sessionState.messageStore.outboundRows(hostProfileID: sessionHost, sessionID: "a").isEmpty)
        #expect(sessionState.messageStore.failedSendReasonsByID[deletedSourceID ?? ""] == nil)
        #expect(!sessionState.messageStore.isPendingOptimisticMessage(deletedSourceID ?? ""))
        #expect(sessionState.messageStore.failedSendReasonsByID.isEmpty)
    }

    /// The server publishes a tool part when the call starts. A snapshot
    /// taken before that does not know the call, and the running card must
    /// survive the reload.
    @Test func reloadKeepsTheToolCallTheServerHasNotPublishedYet() throws {
        let store = MessageStore(defaults: UserDefaults(suiteName: "merge-\(UUID().uuidString)")!)
        store.messages = [MessageWithParts(
            info: assistantMessage(id: "msg_1", sessionID: "s1"),
            parts: [toolPart(id: "msg_1-tool-call_1", messageID: "msg_1", sessionID: "s1", status: "running")]
        )]

        let snapshot = [row(id: "msg_0", sessionID: "s1", text: "hello")]
        let merged = store.mergeInFlightToolCalls(into: snapshot)
        #expect(merged.count == 2)
        #expect(merged.last?.info.id == "msg_1")
        #expect(merged.last?.parts.first?.stateDisplay == "running")

        // A finished call is the server's business again.
        store.messages = [MessageWithParts(
            info: assistantMessage(id: "msg_1", sessionID: "s1"),
            parts: [toolPart(id: "msg_1-tool-call_1", messageID: "msg_1", sessionID: "s1", status: "completed")]
        )]
        #expect(store.mergeInFlightToolCalls(into: snapshot).count == 1)
    }

    /// A snapshot that already knows the call does not get a second card.
    @Test func reloadDoesNotDuplicateAKnownToolCall() throws {
        let store = MessageStore(defaults: UserDefaults(suiteName: "merge-\(UUID().uuidString)")!)
        let part = toolPart(id: "msg_1-tool-call_1", messageID: "msg_1", sessionID: "s1", status: "running")
        store.messages = [MessageWithParts(info: assistantMessage(id: "msg_1", sessionID: "s1"), parts: [part])]

        let snapshot = [MessageWithParts(info: assistantMessage(id: "msg_1", sessionID: "s1"), parts: [part])]
        let merged = store.mergeInFlightToolCalls(into: snapshot)
        #expect(merged.count == 1)
        #expect(merged.first?.parts.count == 1)
    }
}

private func row(id: String, sessionID: String, text: String, completed: Int? = 1) -> MessageWithParts {
    MessageWithParts(
        info: Message(
            id: id,
            sessionID: sessionID,
            role: "assistant",
            parentID: nil,
            providerID: nil,
            modelID: nil,
            model: nil,
            error: nil,
            time: .init(created: 110_000, completed: completed),
            finish: nil,
            tokens: nil,
            cost: nil
        ),
        parts: [Part(
            id: "p-\(id)",
            messageID: id,
            sessionID: sessionID,
            type: "text",
            text: text,
            tool: nil,
            callID: nil,
            state: nil,
            metadata: nil,
            files: nil
        )]
    )
}

private func notFound() -> APIError {
    APIError.httpError(statusCode: 404, data: Data())
}

private func assistantMessage(id: String, sessionID: String) -> Message {
    Message(
        id: id,
        sessionID: sessionID,
        role: "assistant",
        parentID: nil,
        providerID: nil,
        modelID: nil,
        model: nil,
        error: nil,
        time: .init(created: 110_000, completed: nil),
        finish: nil,
        tokens: nil,
        cost: nil
    )
}

private func toolPart(id: String, messageID: String, sessionID: String, status: String) -> Part {
    let json = "{\"status\":\"\(status)\"}"
    let state = try? JSONDecoder().decode(PartStateBridge.self, from: Data(json.utf8))
    return Part(
        id: id,
        messageID: messageID,
        sessionID: sessionID,
        type: "tool",
        text: nil,
        tool: "shell",
        callID: "call_1",
        state: state,
        metadata: nil,
        files: nil
    )
}

@MainActor
private func composerFailureHarness() async -> (api: ReconciliationAPI, state: AppState) {
    let api = ReconciliationAPI()
    await api.armPrompt()
    await api.setPromptError(APIError.invalidURL)
    let state = makeIsolatedAppState(apiClient: api)
    state.currentSessionID = "a"
    state.sessions = [makeSession(id: "a", directory: "/work/a", archived: nil)]
    return (api, state)
}

private func makeSession(id: String, directory: String, archived: Int?, parentID: String? = nil) -> Session {
    Session(
        id: id,
        slug: id,
        projectID: "p1",
        directory: directory,
        parentID: parentID,
        title: id,
        version: "1",
        time: .init(created: 1, updated: 1, archived: archived),
        share: nil,
        summary: nil
    )
}

private func agent(_ name: String) -> AgentInfo {
    AgentInfo(name: name, description: nil, mode: "primary", hidden: false, native: true)
}

private func shortlist(_ modelID: String) -> ModelShortlistItem {
    ModelShortlistItem(providerID: "openai", modelID: modelID, displayName: modelID, shortName: modelID)
}

private func attachment() -> ComposerImageAttachment {
    ComposerImageAttachment(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        filename: "photo.jpg",
        mime: "image/jpeg",
        dataURL: "data:image/jpeg;base64,AAA",
        thumbnailData: Data([0x01]),
        byteSize: 1
    )
}

private func runningActivity(sessionID: String) -> SessionActivity {
    SessionActivity(
        sessionID: sessionID,
        state: .running,
        text: "Running",
        startedAt: Date(timeIntervalSince1970: 100),
        endedAt: nil,
        anchorMessageID: nil
    )
}

private func event(_ json: String) -> SSEEvent {
    try! JSONDecoder().decode(SSEEvent.self, from: Data(json.utf8))
}

private actor IndexedGate {
    private var next = 0
    private var entered = 0
    private var armed = false
    private var released: Set<Int> = []
    private var waiters: [Int: CheckedContinuation<Void, Never>] = [:]
    private var observers: [CheckedContinuation<Int, Never>] = []

    func arm() {
        armed = true
        released.removeAll()
        next = 0
        entered = 0
    }

    func enter() async -> Int {
        let index = next
        next += 1
        entered += 1
        let pending = observers
        observers.removeAll()
        pending.forEach { $0.resume(returning: entered) }
        if armed, !released.contains(index) {
            await withCheckedContinuation { waiters[index] = $0 }
        }
        return index
    }

    func waitUntilEntered(_ count: Int) async {
        if entered >= count { return }
        _ = await withCheckedContinuation { (cont: CheckedContinuation<Int, Never>) in
            if entered >= count {
                cont.resume(returning: entered)
            } else {
                observers.append(cont)
            }
        }
    }

    func release(_ index: Int) {
        released.insert(index)
        waiters.removeValue(forKey: index)?.resume()
    }
}

private actor ReconciliationAPI: APIClientProtocol {
    struct Prompt: Equatable {
        var sessionID: String
        var agent: String
        var modelID: String?
        var directory: String?
    }

    private let inner = MockAPIClient()
    private let messagesGate = IndexedGate()
    private let archiveGate = IndexedGate()
    private let promptGate = IndexedGate()
    private let deleteGate = IndexedGate()
    private var scripts: [[MessageWithParts]] = []
    private var messageErrors: [Int: Error] = [:]
    private var promptError: Error?
    private(set) var prompts: [Prompt] = []
    private(set) var messageLimits: [Int] = []
    private(set) var archiveSessionIDs: [String] = []

    func armMessages() async { await messagesGate.arm() }
    func armArchive() async { await archiveGate.arm() }
    func armPrompt() async { await promptGate.arm() }
    func armDelete() async { await deleteGate.arm() }
    func waitMessages(_ count: Int) async { await messagesGate.waitUntilEntered(count) }
    func waitArchive(_ count: Int = 1) async { await archiveGate.waitUntilEntered(count) }
    func waitPrompt(_ count: Int = 1) async { await promptGate.waitUntilEntered(count) }
    func waitDelete(_ count: Int = 1) async { await deleteGate.waitUntilEntered(count) }
    func releaseMessages(_ index: Int) async { await messagesGate.release(index) }
    func releaseArchive(_ index: Int = 0) async { await archiveGate.release(index) }
    func releasePrompt(_ index: Int = 0) async { await promptGate.release(index) }
    func releaseDelete(_ index: Int = 0) async { await deleteGate.release(index) }
    func setMessageScripts(_ scripts: [[MessageWithParts]]) { self.scripts = scripts }
    func setMessageError(_ index: Int, _ error: Error) { messageErrors[index] = error }
    func setPromptError(_ error: Error?) async {
        promptError = error
        await inner.setPromptError(error)
    }

    func configure(baseURL: String, username: String?, password: String?) {}
    func health() async throws -> HealthResponse { try await inner.health() }
    func projects() async throws -> [Project] { [] }
    func projectCurrent() async throws -> Project? { nil }
    func sessions(directory: String?, limit: Int) async throws -> [Session] { [] }
    func session(sessionID: String) async throws -> Session { try await inner.session(sessionID: sessionID) }
    func createSession(title: String?, directory: String?) async throws -> Session { try await inner.createSession(title: title, directory: directory) }
    func updateSession(sessionID: String, title: String) async throws -> Session { try await inner.updateSession(sessionID: sessionID, title: title) }
    func updateSessionArchived(sessionID: String, archived: Int) async throws -> Session {
        archiveSessionIDs.append(sessionID)
        _ = await archiveGate.enter()
        return makeSession(id: sessionID, directory: "/changed", archived: archived)
    }
    func deleteSession(sessionID: String) async throws {
        _ = await deleteGate.enter()
    }
    func messages(sessionID: String, limit: Int?) async throws -> [MessageWithParts] {
        messageLimits.append(limit ?? 0)
        let index = await messagesGate.enter()
        if let error = messageErrors[index] { throw error }
        if scripts.indices.contains(index) { return scripts[index] }
        return []
    }
    func promptAsync(sessionID: String, messageID: String, text: String, attachments: [ComposerImageAttachment], agent: String, model: Message.ModelInfo?, directory: String?) async throws {
        prompts.append(Prompt(sessionID: sessionID, agent: agent, modelID: model?.modelID, directory: directory))
        _ = await promptGate.enter()
        if let promptError { throw promptError }
        try await inner.promptAsync(sessionID: sessionID, messageID: messageID, text: text, attachments: attachments, agent: agent, model: model, directory: directory)
    }
    func promptStructured(sessionID: String, messageID: String?, text: String, system: String, format: StructuredOutputFormat, agent: String, model: Message.ModelInfo) async throws -> MessageWithParts {
        try await inner.promptStructured(sessionID: sessionID, messageID: messageID, text: text, system: system, format: format, agent: agent, model: model)
    }
    func abort(sessionID: String) async throws {}
    func sessionStatus() async throws -> [String: SessionStatus] { [:] }
    func pendingPermissions() async throws -> [APIClient.PermissionRequest] { [] }
    func respondPermission(sessionID: String, permissionID: String, response: APIClient.PermissionResponse) async throws {}
    func pendingQuestions() async throws -> [QuestionRequest] { [] }
    func replyQuestion(requestID: String, answers: [[String]]) async throws {}
    func rejectQuestion(requestID: String) async throws {}
    func providers() async throws -> ProvidersResponse { try await inner.providers() }
    func providerRegistry() async throws -> ProviderRegistryResponse { try await inner.providerRegistry() }
    func agents() async throws -> [AgentInfo] { [] }
    func sessionDiff(sessionID: String) async throws -> [FileDiff] { [] }
    func sessionTodos(sessionID: String) async throws -> [TodoItem] { [] }
    func fileList(path: String, directory: String?) async throws -> [FileNode] { [] }
    func fileContent(path: String, directory: String?) async throws -> FileContent { FileContent(type: "text", content: "") }
    func findFile(query: String, limit: Int) async throws -> [String] { [] }
    func fileStatus() async throws -> [FileStatusEntry] { [] }
    func forkSession(sessionID: String, messageID: String?) async throws -> Session { try await inner.forkSession(sessionID: sessionID, messageID: messageID) }
    func revertSession(sessionID: String, messageID: String, partID: String?) async throws -> Session {
        try await inner.revertSession(sessionID: sessionID, messageID: messageID, partID: partID)
    }
}
