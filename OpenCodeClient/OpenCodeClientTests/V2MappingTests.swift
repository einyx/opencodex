import Foundation
import Testing
@testable import OpenCodeClient

/// V2 wire shapes measured against upstream `v2.1.3` (see
/// `docs/features/v2_support/plan.md`). These lock the mapping from the V2
/// envelopes into the app's existing models.
struct V2MappingTests {
    // MARK: - Detection

    @Test func v1HealthJSONIsV1() {
        #expect(ServerGenerationProbe.classify(healthStatus: 200, healthBody: Data(#"{"healthy":true,"version":"1.9.4"}"#.utf8)) == .v1)
    }

    @Test func v1HealthWithoutHealthyFlagIsNotV1() {
        #expect(ServerGenerationProbe.classify(healthStatus: 200, healthBody: Data(#"{"version":"1.9.4"}"#.utf8)) == .unrecognized)
    }

    @Test func v1HealthHTMLIsNotV1() {
        // A packaged V2 server answers every unknown path with the SPA shell.
        // That HTML must never be read as a V1 health payload.
        #expect(ServerGenerationProbe.classify(healthStatus: 200, healthBody: Data("<!doctype html><html></html>".utf8)) == .unrecognized)
    }

    @Test func v2InfoJSONIsV2() {
        #expect(ServerGenerationProbe.classify(infoStatus: 200, infoBody: Data(#"{"version":"2.1.3"}"#.utf8)) == .v2)
    }

    @Test func v2InfoWithoutStringVersionIsUnrecognized() {
        #expect(ServerGenerationProbe.classify(infoStatus: 200, infoBody: Data(#"{"version":2}"#.utf8)) == .unrecognized)
    }

    // MARK: - Sessions

    @Test func sessionEnvelopeMapsToAppSession() throws {
        let session = try V2Mapper.session(
            from: Data(#"""
            {"data":{"id":"ses_1","projectID":"prj_1","location":{"directory":"/repo"},"title":"Untitled","version":"2","time":{"created":1,"updated":2}}}
            """#.utf8)
        )
        #expect(session.id == "ses_1")
        #expect(session.slug == "ses_1")
        #expect(session.projectID == "prj_1")
        #expect(session.directory == "/repo")
        #expect(session.title == "Untitled")
        #expect(session.version == "2")
        #expect(session.time.created == 1)
        #expect(session.time.updated == 2)
        #expect(session.time.archived == nil)
        #expect(session.isArchived == false)
    }

    @Test func sessionListEnvelopeMapsEachElement() throws {
        let sessions = try V2Mapper.sessions(
            from: Data(#"{"data":[{"id":"ses_1","projectID":"prj_1","location":{"directory":"/repo"},"title":"A","time":{"created":1,"updated":2}}]}"#.utf8)
        )
        #expect(sessions.count == 1)
        #expect(sessions.first?.id == "ses_1")
    }

    @Test func sessionCopiesServerTokensAndCost() throws {
        let session = try V2Mapper.session(
            from: Data(#"""
            {"data":{"id":"ses_1","projectID":"prj_1","location":{"directory":"/repo"},"title":"A","time":{"created":1,"updated":2},
            "tokens":{"input":10,"output":5,"reasoning":2,"cache":{"read":3,"write":4}},"cost":1.5}}
            """#.utf8)
        )
        #expect(session.tokens?.input == 10)
        #expect(session.tokens?.output == 5)
        #expect(session.tokens?.reasoning == 2)
        #expect(session.tokens?.cache?.read == 3)
        #expect(session.tokens?.total == 24)
        #expect(session.cost == 1.5)
    }

    @Test func archivedSessionKeepsServerArchivedTimestamp() throws {
        let session = try V2Mapper.session(
            from: Data(#"""
            {"data":{"id":"ses_1","projectID":"prj_1","location":{"directory":"/repo"},"title":"A","time":{"created":1,"updated":2,"archived":9}}}
            """#.utf8)
        )
        #expect(session.time.archived == 9)
        #expect(session.isArchived == true)
    }

    // MARK: - Messages

    @Test func userMessageMapsToTextPart() throws {
        let messages = try V2Mapper.messages(from: Data(#"""
        {"data":[{"id":"msg_1","type":"user","text":"hi","time":{"created":1}}]}
        """#.utf8), sessionID: "ses_1")
        #expect(messages.count == 1)
        let message = try #require(messages.first)
        #expect(message.info.id == "msg_1")
        #expect(message.info.role == "user")
        #expect(message.info.sessionID == "ses_1")
        #expect(message.parts.count == 1)
        #expect(message.parts.first?.type == "text")
        #expect(message.parts.first?.text == "hi")
    }

    @Test func assistantMessageMapsTextAndToolContent() throws {
        let messages = try V2Mapper.messages(from: Data(#"""
        {"data":[{"id":"msg_2","type":"assistant","agent":"build","model":{"id":"gpt-6.1-sol","providerID":"openai"},
        "content":[{"type":"text","text":"ok"},{"type":"tool","id":"call_1","name":"bash","state":{"status":"completed","input":{"command":"ls"},"content":[{"type":"text","text":"out"}]}}],
        "time":{"created":2,"completed":3}}]}
        """#.utf8), sessionID: "ses_1")
        let message = try #require(messages.first)
        #expect(message.info.role == "assistant")
        #expect(message.info.providerID == "openai")
        #expect(message.info.modelID == "gpt-6.1-sol")
        #expect(message.info.agent == "build")
        #expect(message.parts.map(\.type) == ["text", "tool"])
        #expect(message.parts[1].tool == "bash")
        #expect(message.parts[1].callID == "call_1")
    }

    /// The REST snapshot and the live stream must build the same part ids, or
    /// one call renders as two cards.
    @Test func partIDsMatchTheLiveStream() throws {
        let messages = try V2Mapper.messages(from: Data(#"""
        {"data":[{"id":"msg_2","type":"assistant",
        "content":[{"type":"reasoning","text":"thinking"},{"type":"text","text":"ok"},
        {"type":"tool","id":"call_1","name":"shell","state":{"status":"running","input":{"command":"ls"}}}],
        "time":{"created":2}}]}
        """#.utf8), sessionID: "ses_1")
        let message = try #require(messages.first)
        #expect(message.parts.map(\.id) == [
            "msg_2-reasoning-0",
            "msg_2-text-0",
            "msg_2-tool-call_1",
        ])
        #expect(message.parts[2].id == V2EventTranslator.toolPartID(messageID: "msg_2", callID: "call_1"))
    }

    /// V2 counts the ordinals per part type: the content array holds the
    /// reasoning first, so the text part must not be numbered after it.
    @Test func textAndReasoningAreNumberedPerType() throws {
        let messages = try V2Mapper.messages(from: Data(#"""
        {"data":[{"id":"msg_2","type":"assistant",
        "content":[{"type":"reasoning","text":"one"},{"type":"text","text":"a"},{"type":"reasoning","text":"two"},{"type":"text","text":"b"}],
        "time":{"created":2}}]}
        """#.utf8), sessionID: "ses_1")
        let message = try #require(messages.first)
        #expect(message.parts.map(\.id) == [
            "msg_2-reasoning-0",
            "msg_2-text-0",
            "msg_2-reasoning-1",
            "msg_2-text-1",
        ])
    }

    @Test func idleAndUnknownMessageTypesAreSkipped() throws {
        let messages = try V2Mapper.messages(from: Data(#"""
        {"data":[{"id":"msg_1","type":"user","text":"hi","time":{"created":1}},{"id":"msg_2","type":"idle","time":{"created":2}}]}
        """#.utf8), sessionID: "ses_1")
        #expect(messages.count == 1)
        #expect(messages.first?.info.id == "msg_1")
    }

    @Test func assistantMessageTakesThePrecedingUserMessageAsParent() throws {
        let json = #"{"data":[{"id":"msg_1","type":"user","text":"hi","time":{"created":1}},{"id":"msg_2","type":"assistant","content":[{"type":"text","text":"ok"}],"time":{"created":2}}]}"#
        let messages = try V2Mapper.messages(from: Data(json.utf8), sessionID: "ses_1")
        #expect(messages.count == 2)
        // A user message is nobody's child.
        #expect(messages[0].info.parentID == nil)
        #expect(messages[1].info.parentID == "msg_1")
    }

    @Test func descendingServerPayloadBecomesAnAscendingTranscript() throws {
        // V2 serves the transcript newest first (`order=desc` is the default).
        // The app renders oldest first, so the mapper has to put it back in
        // chronological order and derive the parents from that order.
        let json = #"""
        {"data":[
        {"id":"msg_3","type":"assistant","content":[{"type":"text","text":"second answer"}],"time":{"created":30}},
        {"id":"msg_2","type":"user","text":"second question","time":{"created":20}},
        {"id":"msg_1","type":"assistant","content":[{"type":"text","text":"first answer"}],"time":{"created":10}},
        {"id":"msg_0","type":"user","text":"first question","time":{"created":5}}
        ]}
        """#
        let messages = try V2Mapper.messages(from: Data(json.utf8), sessionID: "ses_1")
        #expect(messages.map(\.info.id) == ["msg_0", "msg_1", "msg_2", "msg_3"])
        // Each assistant hangs off the user message that came before it.
        #expect(messages[0].info.parentID == nil)
        #expect(messages[1].info.parentID == "msg_0")
        #expect(messages[2].info.parentID == nil)
        #expect(messages[3].info.parentID == "msg_2")
    }

    @Test func messagesWithTheSameTimestampAreOrderedByID() throws {
        let json = #"""
        {"data":[
        {"id":"msg_b","type":"user","text":"second","time":{"created":7}},
        {"id":"msg_a","type":"user","text":"first","time":{"created":7}}
        ]}
        """#
        let messages = try V2Mapper.messages(from: Data(json.utf8), sessionID: "ses_1")
        #expect(messages.map(\.info.id) == ["msg_a", "msg_b"])
    }

    @Test func emptyMessageEnvelopeIsEmptyNotAnError() throws {
        #expect(try V2Mapper.messages(from: Data(#"{"data":[]}"#.utf8), sessionID: "ses_1").isEmpty)
    }

    // MARK: - Message pagination

    @Test func v2CursorIsRecognisedAndAForeignCursorIsNot() {
        // A V2 cursor is base64url JSON carrying the ordering and the
        // direction to walk. The V1 `before` cursor is not interchangeable.
        let payload = #"{"id":"msg_1","order":"desc","direction":"next"}"#
        let encoded = Data(payload.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        #expect(APIClient.v2MessageCursor(encoded) == encoded)
        #expect(APIClient.v2MessageCursor("eyJpZCI6Im1zZ18xIn0") == nil)
        #expect(APIClient.v2MessageCursor("") == nil)
    }

    @Test func v2NextCursorComesFromTheResponseBody() {
        let json = #"{"data":[],"cursor":{"previous":null,"next":"abc"}}"#
        #expect(APIClient.v2MessageNextCursor(Data(json.utf8)) == "abc")
        let empty = #"{"data":[],"cursor":{"previous":null,"next":null}}"#
        #expect(APIClient.v2MessageNextCursor(Data(empty.utf8)) == nil)
    }

    // MARK: - Providers, models, agents

    @Test func providerEnvelopeMapsToConfigProvider() throws {
        let providers = try V2Mapper.providers(from: Data(#"""
        {"data":[{"id":"openai","name":"OpenAI","activation":"auto"}]}
        """#.utf8))
        #expect(providers.count == 1)
        #expect(providers.first?.id == "openai")
        #expect(providers.first?.name == "OpenAI")
        #expect(providers.first?.models.isEmpty == true)
    }

    @Test func providerRegistryKeepsOnlyEnabledProvidersConnected() throws {
        let registry = try V2Mapper.providerRegistry(from: Data(#"""
        {"data":[{"id":"openai","name":"OpenAI","activation":"auto"},{"id":"off","name":"Off","activation":"disabled"}]}
        """#.utf8))
        #expect(registry.providers.count == 2)
        #expect(registry.connectedProviderIDs == ["openai"])
    }

    @Test func modelEnvelopeMapsCapabilitiesAndLimits() throws {
        let models = try V2Mapper.models(from: Data(#"""
        {"data":[{"id":"gpt-5","modelID":"gpt-5","providerID":"openai","name":"GPT","capabilities":{"tools":true,"input":["text","image"],"output":["text"]},"limit":{"context":8,"output":2}}]}
        """#.utf8))
        let model = try #require(models.first)
        #expect(model.id == "gpt-5")
        #expect(model.providerID == "openai")
        #expect(model.name == "GPT")
        #expect(model.capabilities?.toolCall == true)
        #expect(model.capabilities?.attachment == true)
        #expect(model.limit?.context == 8)
        #expect(model.limit?.output == 2)
    }

    @Test func agentEnvelopeMapsNameAndMode() throws {
        let agents = try V2Mapper.agents(from: Data(#"""
        {"data":[{"id":"build","name":"Build","description":"Primary","mode":"primary","hidden":false}]}
        """#.utf8))
        let agent = try #require(agents.first)
        #expect(agent.name == "Build")
        #expect(agent.description == "Primary")
        #expect(agent.mode == "primary")
        #expect(agent.hidden == false)
    }

    // MARK: - Files, diffs, projects

    @Test func fileListEnvelopeMapsPathAndType() throws {
        let files = try V2Mapper.fileList(from: Data(#"""
        {"data":[{"path":"code/AppState.swift","type":"file"}]}
        """#.utf8))
        #expect(files.count == 1)
        #expect(files.first?.path == "code/AppState.swift")
        #expect(files.first?.type == "file")
        #expect(files.first?.name == "AppState.swift")
    }

    @Test func findEnvelopeMapsPaths() throws {
        #expect(try V2Mapper.foundPaths(from: Data(#"{"data":[{"path":"a.swift","type":"file"}]}"#.utf8)) == ["a.swift"])
    }

    @Test func diffEnvelopeMapsPatchToAfter() throws {
        let diffs = try V2Mapper.diff(from: Data(#"""
        {"data":[{"file":"a.swift","patch":"+let x","additions":1,"deletions":0,"status":"added"}]}
        """#.utf8))
        let diff = try #require(diffs.first)
        #expect(diff.file == "a.swift")
        #expect(diff.after == "+let x")
        #expect(diff.before == "")
        #expect(diff.additions == 1)
        #expect(diff.status == "added")
    }

    @Test func projectEnvelopeIsABareArray() throws {
        let projects = try V2Mapper.projects(from: Data(#"""
        [{"id":"prj_1","canonical":"/repo","vcs":"git","time":{"created":1,"updated":2},"sandboxes":[]}]
        """#.utf8))
        #expect(projects.count == 1)
        #expect(projects.first?.worktree == "/repo")
    }

    @Test func locationEnvelopeFallsBackToAPathOnlyProject() throws {
        let project = try V2Mapper.currentProject(from: Data(#"""
        {"directory":"/repo","project":{"id":"prj_1","directory":"/repo","canonical":"/repo"}}
        """#.utf8))
        #expect(project?.worktree == "/repo")
        #expect(project?.id == "prj_1")
    }

    // MARK: - Permissions and forms

    @Test func permissionEnvelopeMapsActionAndResources() throws {
        let permissions = try V2Mapper.permissions(from: Data(#"""
        {"data":[{"id":"per_1","sessionID":"ses_1","action":"read","resources":["*.env"],"source":{"type":"tool","messageID":"msg_1","id":"call_1"}}]}
        """#.utf8))
        let permission = try #require(permissions.first)
        #expect(permission.id == "per_1")
        #expect(permission.sessionID == "ses_1")
        #expect(permission.permission == "read")
        #expect(permission.patterns == ["*.env"])
        #expect(permission.tool?.callID == "call_1")
    }

    @Test func formEnvelopeMapsFieldsToQuestions() throws {
        let questions = try V2Mapper.questions(from: Data(#"""
        {"data":[{"id":"frm_1","sessionID":"ses_1","title":"Pick","fields":[{"key":"color","type":"string","options":[{"value":"red","label":"Red"}]}]}]}
        """#.utf8))
        let question = try #require(questions.first)
        #expect(question.id == "frm_1")
        #expect(question.sessionID == "ses_1")
        #expect(question.questions.count == 1)
        #expect(question.questions.first?.header == "color")
        #expect(question.questions.first?.options.first?.label == "Red")
    }

    @Test func formOptionValuesAreKeptForTheReplyTable() throws {
        let table = try V2Mapper.formReplyTable(from: Data(#"""
        {"data":[{"id":"frm_1","sessionID":"ses_1","title":"Pick","fields":[{"key":"color","type":"string","options":[{"value":"red","label":"Red"}]}]}]}
        """#.utf8))
        let entry = try #require(table["frm_1"])
        #expect(entry.sessionID == "ses_1")
        #expect(entry.values(for: "color", labels: ["Red"]) == ["red"])
    }

    // MARK: - Active sessions

    @Test func activeSessionEnvelopeMapsRunningToBusy() throws {
        let statuses = try V2Mapper.activeSessionStatuses(from: Data(#"""
        {"data":{"ses_1":{"type":"running"}}}
        """#.utf8))
        #expect(statuses["ses_1"]?.type == "busy")
    }

    @Test func activeSessionEnvelopeWithEmptyDataIsEmpty() throws {
        #expect(try V2Mapper.activeSessionStatuses(from: Data(#"{"data":{}}"#.utf8)).isEmpty)
    }

    // MARK: - Request bodies

    @Test func v2PromptBodyUsesTextAndFiles() throws {
        let body = try V2Mapper.promptBody(text: "hi", files: [])
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["text"] as? String == "hi")
        #expect(object["parts"] == nil)
        #expect(object["files"] == nil)
    }

    @Test func v2PromptBodyCarriesImageFilesAsDataURIs() throws {
        let attachment = ComposerImageAttachment(
            id: UUID(),
            filename: "a.png",
            mime: "image/png",
            dataURL: "data:image/png;base64,aGVsbG8=",
            thumbnailData: Data(),
            byteSize: 5
        )
        let body = try V2Mapper.promptBody(text: "hi", files: [attachment])
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let files = try #require(object["files"] as? [[String: Any]])
        #expect(files.first?["uri"] as? String == "data:image/png;base64,aGVsbG8=")
        #expect(files.first?["name"] as? String == "a.png")
        #expect(files.first?["mime"] == nil)
    }

    @Test func v2ArchiveBodyUsesTopLevelArchivedBoolean() throws {
        let body = try V2Mapper.archiveBody(archived: true)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["archived"] as? Bool == true)
        #expect(object["time"] == nil)
    }
}
