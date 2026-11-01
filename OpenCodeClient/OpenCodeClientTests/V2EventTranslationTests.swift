import Foundation
import Testing
@testable import OpenCodeClient

/// V2 SSE frames translated into the app's V1 event shapes. Frame shapes
/// measured against upstream `v2.1.3`; see `docs/features/v2_support/plan.md`.
struct V2EventTranslationTests {
    private func translate(_ json: String) -> SSEEvent? {
        var translator = V2EventTranslator()
        return translate(json, with: &translator)
    }

    /// The translator is stateful (it carries the tool call state forward), so
    /// a sequence of frames needs one instance.
    private func translate(_ json: String, with translator: inout V2EventTranslator) -> SSEEvent? {
        guard let frame = try? JSONDecoder().decode(V2EventTranslator.Frame.self, from: Data(json.utf8)) else {
            return nil
        }
        return translator.translate(frame)
    }

    private func properties(_ event: SSEEvent?) -> [String: Any] {
        (event?.payload.properties ?? [:]).mapValues(\.value)
    }

    private func part(_ event: SSEEvent?) -> [String: Any]? {
        properties(event)["part"] as? [String: Any]
    }

    private func partState(_ event: SSEEvent?) -> [String: Any]? {
        part(event)?["state"] as? [String: Any]
    }

    @Test func serverConnectedBecomesTheServerConnectedEvent() throws {
        let event = try #require(translate(#"{"id":"e1","type":"server.connected","data":{}}"#))
        #expect(event.payload.type == "server.connected")
        #expect(event.payload.properties?.isEmpty == true)
    }

    @Test func sessionStatusKeepsItsPayload() throws {
        let json = #"{"id":"e2","type":"session.status","data":{"sessionID":"ses_1","status":{"type":"busy"}}}"#
        let event = try #require(translate(json))
        #expect(event.payload.type == "session.status")
        let props = properties(event)
        #expect(props["sessionID"] as? String == "ses_1")
        #expect((props["status"] as? [String: Any])?["type"] as? String == "busy")
    }

    @Test func sessionIdleBecomesAnIdleStatus() throws {
        let json = #"{"id":"e3","type":"session.idle","data":{"sessionID":"ses_1"}}"#
        let event = try #require(translate(json))
        #expect(event.payload.type == "session.status")
        let props = properties(event)
        #expect(props["sessionID"] as? String == "ses_1")
        #expect((props["status"] as? [String: Any])?["type"] as? String == "idle")
    }

    @Test func sessionRenamedAsksForAFreshRead() throws {
        let json = #"{"id":"e4","type":"session.renamed","data":{"sessionID":"ses_1"}}"#
        let event = try #require(translate(json))
        #expect(event.payload.type == "session.updated")
        let props = properties(event)
        #expect(props["sessionID"] as? String == "ses_1")
        #expect(props["v2Refresh"] as? Bool == true)
    }

    @Test func sessionDeletedCarriesItsSessionID() throws {
        let json = #"{"id":"e5","type":"session.deleted","data":{"sessionID":"ses_1"}}"#
        let event = try #require(translate(json))
        #expect(event.payload.type == "session.deleted")
        #expect(properties(event)["sessionID"] as? String == "ses_1")
    }

    @Test func textDeltaBecomesAPartDeltaWithAStablePartID() throws {
        let json = #"{"id":"e6","type":"session.text.delta","data":{"sessionID":"ses_1","assistantMessageID":"msg_1","ordinal":0,"delta":"hi"}}"#
        let first = try #require(translate(json))
        #expect(first.payload.type == "message.part.delta")
        let props = properties(first)
        #expect(props["partID"] as? String == "msg_1-text-0")
        #expect(props["field"] as? String == "text")
        #expect(props["delta"] as? String == "hi")

        // The same ordinal yields the same part id, so a reconnect converges.
        let again = try #require(translate(json))
        #expect(properties(again)["partID"] as? String == "msg_1-text-0")
    }

    @Test func textEndedCarriesTheWholeText() throws {
        let json = #"{"id":"e8","type":"session.text.ended","data":{"sessionID":"ses_1","assistantMessageID":"msg_1","ordinal":0,"text":"hi there"}}"#
        let event = try #require(translate(json))
        #expect(event.payload.type == "message.part.updated")
        let part = properties(event)["part"] as? [String: Any]
        #expect(part?["id"] as? String == "msg_1-text-0")
        #expect(part?["type"] as? String == "text")
        #expect(part?["text"] as? String == "hi there")
    }

    @Test func reasoningDeltaIsIgnored() {
        let json = #"{"id":"e9","type":"session.reasoning.delta","data":{"sessionID":"ses_1","assistantMessageID":"msg_1","ordinal":0,"delta":"..."}}"#
        #expect(translate(json) == nil)
    }

    @Test func messageContentUpdateAsksForAFreshTranscript() throws {
        let json = #"{"id":"e10","type":"session.message.content.updated","data":{"sessionID":"ses_1"}}"#
        let event = try #require(translate(json))
        #expect(event.payload.type == "message.updated")
    }

    @Test func permissionAskedMapsActionAndResources() throws {
        let json = #"{"id":"e11","type":"permission.asked","data":{"id":"per_1","sessionID":"ses_1","action":"read","resources":["*.env"],"source":{"type":"tool","messageID":"msg_1","id":"call_1"}}}"#
        let event = try #require(translate(json))
        #expect(event.payload.type == "permission.asked")
        let props = properties(event)
        #expect(props["permission"] as? String == "read")
        #expect(props["patterns"] as? [String] == ["*.env"])
        let tool = props["tool"] as? [String: Any]
        #expect(tool?["callID"] as? String == "call_1")
    }

    @Test func formCreatedBecomesAQuestion() throws {
        let json = #"{"id":"e12","type":"form.created","data":{"form":{"id":"frm_1","sessionID":"ses_1","title":"Pick","fields":[{"key":"color","type":"string","options":[{"value":"red","label":"Red"}]}]}}}"#
        let event = try #require(translate(json))
        #expect(event.payload.type == "question.asked")
        let props = properties(event)
        #expect(props["id"] as? String == "frm_1")
        let questions = props["questions"] as? [[String: Any]]
        #expect(questions?.first?["header"] as? String == "color")
        let options = questions?.first?["options"] as? [[String: Any]]
        #expect(options?.first?["label"] as? String == "Red")
    }

    /// The form has to reach the client with its option values: the app shows
    /// the labels, the server wants the values, and the poll that lists the
    /// forms has not seen this one yet.
    @Test @MainActor func aFormFromTheStreamRegistersItsReplyTable() async throws {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        var translator = V2EventTranslator()
        let json = #"{"id":"e12","type":"form.created","data":{"form":{"id":"frm_1","sessionID":"ses_1","title":"Pick","fields":[{"key":"color","type":"string","options":[{"value":"red","label":"Red"}]}]}}}"#
        let event = try #require(translate(json, with: &translator))

        await state.handleSSEEvent(event)

        #expect(state.pendingQuestions.first?.id == "frm_1")
        let forms = await mock.rememberedFormTables
        let registered = try #require(forms.first)
        #expect(registered["id"] as? String == "frm_1")
        let fields = try #require(registered["fields"] as? [[String: Any]])
        let options = try #require(fields.first?["options"] as? [[String: Any]])
        #expect(options.first?["value"] as? String == "red")
    }

    @Test func formRepliedRemovesTheCard() throws {
        let json = #"{"id":"e13","type":"form.replied","data":{"id":"frm_1","sessionID":"ses_1"}}"#
        let event = try #require(translate(json))
        #expect(event.payload.type == "question.rejected")
        #expect(properties(event)["id"] as? String == "frm_1")
    }

    @Test func executionFailedBecomesASessionError() throws {
        let json = #"{"id":"e14","type":"session.execution.failed","data":{"sessionID":"ses_1","error":{"type":"ProviderError","message":"boom"}}}"#
        let event = try #require(translate(json))
        #expect(event.payload.type == "session.error")
        let props = properties(event)
        let error = props["error"] as? [String: Any]
        #expect(error?["name"] as? String == "ProviderError")
        #expect((error?["data"] as? [String: Any])?["message"] as? String == "boom")
    }

    // MARK: - Tool calls

    /// The six frames V2 splits one tool call over, captured from a live
    /// `opencode 2.1.3` server.
    private static let toolInputStarted = #"{"id":"t1","type":"session.tool.input.started","data":{"sessionID":"ses_1","assistantMessageID":"msg_1","id":"call_1","name":"shell"}}"#
    private static let toolInputEnded = #"{"id":"t2","type":"session.tool.input.ended","data":{"sessionID":"ses_1","assistantMessageID":"msg_1","id":"call_1","text":"{\"command\":\"echo hi\"}"}}"#
    private static let toolCalled = #"{"id":"t3","type":"session.tool.called","data":{"sessionID":"ses_1","assistantMessageID":"msg_1","id":"call_1","input":{"command":"echo hi"},"executed":false}}"#
    private static let toolProgress = #"{"id":"t4","type":"session.tool.progress","data":{"sessionID":"ses_1","assistantMessageID":"msg_1","id":"call_1","metadata":{"shellID":"sh_1"}}}"#
    private static let toolSuccess = #"{"id":"t5","type":"session.tool.success","data":{"sessionID":"ses_1","assistantMessageID":"msg_1","id":"call_1","content":[{"type":"text","text":"hi\n"}],"metadata":{"status":"completed","exit":0},"executed":false}}"#
    private static let toolFailed = #"{"id":"t6","type":"session.tool.failed","data":{"sessionID":"ses_1","assistantMessageID":"msg_1","id":"call_1","error":{"type":"tool.execution","message":"File not found"},"executed":false}}"#

    @Test func toolInputStartedCreatesAPendingToolPart() throws {
        let event = try #require(translate(Self.toolInputStarted))
        #expect(event.payload.type == "message.part.updated")
        let part = try #require(part(event))
        #expect(part["type"] as? String == "tool")
        #expect(part["id"] as? String == "msg_1-tool-call_1")
        #expect(part["messageID"] as? String == "msg_1")
        #expect(part["sessionID"] as? String == "ses_1")
        #expect(part["tool"] as? String == "shell")
        #expect(part["callID"] as? String == "call_1")
        #expect(partState(event)?["status"] as? String == "pending")
    }

    @Test func toolCalledRunsTheCallAndCarriesTheInput() throws {
        var translator = V2EventTranslator()
        _ = translate(Self.toolInputStarted, with: &translator)
        _ = translate(Self.toolInputEnded, with: &translator)
        let event = try #require(translate(Self.toolCalled, with: &translator))
        #expect(partState(event)?["status"] as? String == "running")
        let input = try #require(partState(event)?["input"] as? [String: Any])
        #expect(input["command"] as? String == "echo hi")
        // The name the first frame delivered is carried forward.
        #expect(part(event)?["tool"] as? String == "shell")
    }

    @Test func toolInputEndedParsesTheArgumentsOnItsOwn() throws {
        var translator = V2EventTranslator()
        _ = translate(Self.toolInputStarted, with: &translator)
        let event = try #require(translate(Self.toolInputEnded, with: &translator))
        let input = try #require(partState(event)?["input"] as? [String: Any])
        #expect(input["command"] as? String == "echo hi")
        #expect(partState(event)?["status"] as? String == "pending")
    }

    @Test func toolProgressKeepsTheCallRunningAndAddsItsMetadata() throws {
        var translator = V2EventTranslator()
        _ = translate(Self.toolCalled, with: &translator)
        let event = try #require(translate(Self.toolProgress, with: &translator))
        #expect(partState(event)?["status"] as? String == "running")
        let metadata = try #require(partState(event)?["metadata"] as? [String: Any])
        #expect(metadata["shellID"] as? String == "sh_1")
    }

    @Test func toolSuccessCompletesTheCallWithItsOutput() throws {
        var translator = V2EventTranslator()
        _ = translate(Self.toolCalled, with: &translator)
        let event = try #require(translate(Self.toolSuccess, with: &translator))
        #expect(partState(event)?["status"] as? String == "completed")
        #expect(partState(event)?["output"] as? String == "hi\n")
        #expect(part(event)?["id"] as? String == "msg_1-tool-call_1")
    }

    @Test func toolFailedEndsTheCallWithItsError() throws {
        var translator = V2EventTranslator()
        _ = translate(Self.toolCalled, with: &translator)
        let event = try #require(translate(Self.toolFailed, with: &translator))
        #expect(partState(event)?["status"] as? String == "error")
        #expect(partState(event)?["error"] as? String == "File not found")
    }

    @Test func toolFramesThatArriveWithoutAnEarlierFrameStillRender() throws {
        // A success frame can arrive without the start frame (the app
        // reconnected mid-call).
        let event = try #require(translate(Self.toolSuccess))
        #expect(part(event)?["id"] as? String == "msg_1-tool-call_1")
        #expect(partState(event)?["status"] as? String == "completed")
    }

    @Test func toolPartIDIsTheSameOnTheStreamAndInTheSnapshot() throws {
        // The live part and the REST part must share the id, or one call
        // renders as two cards.
        let event = try #require(translate(Self.toolInputStarted))
        let streamID = try #require(part(event)?["id"] as? String)
        #expect(streamID == V2EventTranslator.toolPartID(messageID: "msg_1", callID: "call_1"))
    }
}
