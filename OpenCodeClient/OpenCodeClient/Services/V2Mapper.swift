import Foundation

/// Translates OpenCode V2 wire payloads into the app's existing models.
///
/// V2 wraps every payload in `{"data": …}` and renames most fields. The UI,
/// `MessageStore`, and the SSE handlers keep their current shapes: this mapper
/// is the only place that knows the V2 shapes.
///
/// Shapes measured against upstream `v2.1.3`; see
/// `docs/features/v2_support/plan.md`.
nonisolated enum V2Mapper {
    // MARK: - Envelope

    /// Unwrap `{"data": …}`. A payload that is already a bare array or object
    /// is accepted too, because a V2 deployment may serve either envelope.
    static func unwrap(_ data: Data) throws -> Any {
        let object = try JSONSerialization.jsonObject(with: data)
        if let dictionary = object as? [String: Any], let payload = dictionary["data"] {
            return payload
        }
        return object
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let payload = try unwrap(data)
        guard JSONSerialization.isValidJSONObject(payload),
              let encoded = try? JSONSerialization.data(withJSONObject: payload) else {
            throw V2MappingError.malformed
        }
        return try JSONDecoder().decode(type, from: encoded)
    }

    // MARK: - Sessions

    static func session(from data: Data) throws -> Session {
        try decode(V2Session.self, from: data).session()
    }

    static func sessions(from data: Data) throws -> [Session] {
        let payload = try unwrap(data)
        guard let rows = payload as? [Any] else { throw V2MappingError.malformed }
        return rows.compactMap { row in
            guard let dictionary = row as? [String: Any],
                  let encoded = try? JSONSerialization.data(withJSONObject: dictionary),
                  let session = try? JSONDecoder().decode(V2Session.self, from: encoded) else {
                return nil
            }
            return session.session()
        }
    }

    // MARK: - Messages

    /// Map a V2 message list. `sessionID` is the queried session: V2 messages
    /// do not carry it.
    static func messages(from data: Data, sessionID: String) throws -> [MessageWithParts] {
        let payload = try unwrap(data)
        guard let rows = payload as? [Any] else { throw V2MappingError.malformed }

        // V2 serves the transcript newest first (`order=desc` is the default),
        // while the app renders messages oldest first. Sort chronologically
        // before deriving parents so the transcript reads in order.
        var decoded: [(created: Int, id: String, wire: V2Message)] = []
        for row in rows {
            guard let dictionary = row as? [String: Any],
                  let encoded = try? JSONSerialization.data(withJSONObject: dictionary),
                  let wire = try? JSONDecoder().decode(V2Message.self, from: encoded) else {
                continue
            }
            decoded.append((created: wire.time.created, id: wire.id, wire: wire))
        }
        decoded.sort { lhs, rhs in
            if lhs.created != rhs.created { return lhs.created < rhs.created }
            return lhs.id < rhs.id
        }

        var messages: [MessageWithParts] = []
        var previousUserMessageID: String?

        for entry in decoded {
            let wire = entry.wire
            // The parent of an assistant message is the nearest preceding
            // user message in the same list. V2 messages carry no parent.
            let parentID: String?
            switch wire.type {
            case "user":
                parentID = nil
                previousUserMessageID = wire.id
            case "assistant":
                parentID = previousUserMessageID
            default:
                // `idle`, `system`, `synthetic` and friends are not transcript
                // rows the app renders.
                continue
            }
            messages.append(wire.message(sessionID: sessionID, parentID: parentID))
        }
        return messages
    }

    // MARK: - Providers, models, agents

    static func providers(from data: Data) throws -> [ConfigProvider] {
        let payload = try unwrap(data)
        guard let rows = payload as? [Any] else { throw V2MappingError.malformed }
        return rows.compactMap { row in
            guard let dictionary = row as? [String: Any],
                  let encoded = try? JSONSerialization.data(withJSONObject: dictionary),
                  let wire = try? JSONDecoder().decode(V2Provider.self, from: encoded) else {
                return nil
            }
            return ConfigProvider(id: wire.id, name: wire.name, models: [:])
        }
    }

    /// The provider registry, plus the ids that are usable. A provider is
    /// connected unless the server reports it as disabled.
    static func providerRegistry(from data: Data) throws -> ProviderRegistryResponse {
        let payload = try unwrap(data)
        guard let rows = payload as? [Any] else { throw V2MappingError.malformed }
        var providers: [ConfigProvider] = []
        var connected: [String] = []
        for row in rows {
            guard let dictionary = row as? [String: Any],
                  let encoded = try? JSONSerialization.data(withJSONObject: dictionary),
                  let wire = try? JSONDecoder().decode(V2Provider.self, from: encoded) else {
                continue
            }
            providers.append(ConfigProvider(id: wire.id, name: wire.name, models: [:]))
            if wire.activation != "disabled" {
                connected.append(wire.id)
            }
        }
        return ProviderRegistryResponse(providers: providers, connectedProviderIDs: connected)
    }

    static func models(from data: Data) throws -> [ProviderModel] {
        let payload = try unwrap(data)
        guard let rows = payload as? [Any] else { throw V2MappingError.malformed }
        return rows.compactMap { row in
            guard let dictionary = row as? [String: Any],
                  let encoded = try? JSONSerialization.data(withJSONObject: dictionary),
                  let wire = try? JSONDecoder().decode(V2Model.self, from: encoded) else {
                return nil
            }
            return wire.model()
        }
    }

    static func agents(from data: Data) throws -> [AgentInfo] {
        let payload = try unwrap(data)
        guard let rows = payload as? [Any] else { throw V2MappingError.malformed }
        return rows.compactMap { row in
            guard let dictionary = row as? [String: Any],
                  let encoded = try? JSONSerialization.data(withJSONObject: dictionary),
                  let wire = try? JSONDecoder().decode(V2Agent.self, from: encoded) else {
                return nil
            }
            return AgentInfo(
                name: wire.name?.isEmpty == false ? wire.name! : wire.id,
                description: wire.description,
                mode: wire.mode,
                hidden: wire.hidden,
                native: nil
            )
        }
    }

    // MARK: - Files, diffs, projects

    static func fileList(from data: Data) throws -> [FileNode] {
        let payload = try unwrap(data)
        guard let rows = payload as? [Any] else { throw V2MappingError.malformed }
        return rows.compactMap { row in
            guard let dictionary = row as? [String: Any],
                  let encoded = try? JSONSerialization.data(withJSONObject: dictionary),
                  let wire = try? JSONDecoder().decode(V2FileNode.self, from: encoded) else {
                return nil
            }
            return FileNode(
                name: (wire.path as NSString).lastPathComponent,
                path: wire.path,
                absolute: nil,
                type: wire.type,
                ignored: nil
            )
        }
    }

    static func foundPaths(from data: Data) throws -> [String] {
        let payload = try unwrap(data)
        guard let rows = payload as? [Any] else { throw V2MappingError.malformed }
        return rows.compactMap { row in
            (row as? [String: Any])?["path"] as? String
        }
    }

    static func diff(from data: Data) throws -> [FileDiff] {
        let payload = try unwrap(data)
        guard let rows = payload as? [Any] else { throw V2MappingError.malformed }
        return rows.compactMap { row in
            guard let dictionary = row as? [String: Any],
                  let encoded = try? JSONSerialization.data(withJSONObject: dictionary),
                  let wire = try? JSONDecoder().decode(V2Diff.self, from: encoded) else {
                return nil
            }
            return FileDiff(
                file: wire.file,
                before: "",
                after: wire.patch,
                additions: wire.additions ?? 0,
                deletions: wire.deletions ?? 0,
                status: wire.status,
                patchText: wire.patch
            )
        }
    }

    /// `GET /api/project` returns a bare array.
    static func projects(from data: Data) throws -> [Project] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let rows = object as? [Any] else { throw V2MappingError.malformed }
        return rows.compactMap { row in
            guard let dictionary = row as? [String: Any],
                  let encoded = try? JSONSerialization.data(withJSONObject: dictionary),
                  let wire = try? JSONDecoder().decode(V2Project.self, from: encoded) else {
                return nil
            }
            return Project(
                id: wire.id,
                worktree: wire.canonical,
                vcs: wire.vcs,
                icon: nil,
                time: wire.time.map { Project.TimeInfo(created: $0.created, updated: $0.updated) },
                sandboxes: []
            )
        }
    }

    /// `GET /api/location` carries the current directory and project.
    static func currentProject(from data: Data) throws -> Project? {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else { throw V2MappingError.malformed }
        let directory = dictionary["directory"] as? String
        let project = dictionary["project"] as? [String: Any]
        let id = project?["id"] as? String ?? directory ?? ""
        let worktree = (project?["canonical"] as? String)
            ?? (project?["directory"] as? String)
            ?? directory
        guard let worktree, !worktree.isEmpty else { return nil }
        return Project(
            id: id,
            worktree: worktree,
            vcs: nil,
            icon: nil,
            time: nil,
            sandboxes: []
        )
    }

    // MARK: - Permissions and forms

    static func permissions(from data: Data) throws -> [APIClient.PermissionRequest] {
        let payload = try unwrap(data)
        guard let rows = payload as? [Any] else { throw V2MappingError.malformed }
        return rows.compactMap { row in
            guard let dictionary = row as? [String: Any],
                  let encoded = try? JSONSerialization.data(withJSONObject: dictionary),
                  let wire = try? JSONDecoder().decode(V2Permission.self, from: encoded) else {
                return nil
            }
            let source = wire.source
            return APIClient.PermissionRequest(
                id: wire.id,
                sessionID: wire.sessionID,
                permission: wire.action,
                patterns: wire.resources,
                metadata: nil,
                always: nil,
                tool: source.map {
                    APIClient.PermissionRequest.ToolRef(messageID: $0.messageID, callID: $0.id)
                }
            )
        }
    }

    static func questions(from data: Data) throws -> [QuestionRequest] {
        let payload = try unwrap(data)
        guard let rows = payload as? [Any] else { throw V2MappingError.malformed }
        return rows.compactMap { row -> QuestionRequest? in
            guard let dictionary = row as? [String: Any],
                  let encoded = try? JSONSerialization.data(withJSONObject: dictionary),
                  let wire = try? JSONDecoder().decode(V2Form.self, from: encoded) else {
                return nil
            }
            let questions = wire.fields.compactMap { field -> QuestionInfo? in
                let options = (field.options ?? []).map { option in
                    QuestionOption(label: option.label, description: option.description ?? "")
                }
                return QuestionInfo(
                    question: field.title ?? field.key,
                    header: field.key,
                    options: options,
                    multiple: field.type == "multiselect" ? true : nil,
                    custom: field.type == "string" && options.isEmpty ? true : nil
                )
            }
            guard !questions.isEmpty else { return nil }
            return QuestionRequest(id: wire.id, sessionID: wire.sessionID, questions: questions, tool: nil)
        }
    }

    /// V2 answers a form with `{key: value}`, where the value is the option's
    /// `value` — not its label. The app replies with labels, so the mapping
    /// from label to value is kept per form.
    static func formReplyTable(from data: Data) throws -> [String: FormReplyEntry] {
        let payload = try unwrap(data)
        guard let rows = payload as? [Any] else { throw V2MappingError.malformed }
        var table: [String: FormReplyEntry] = [:]
        for row in rows {
            guard let dictionary = row as? [String: Any],
                  let encoded = try? JSONSerialization.data(withJSONObject: dictionary),
                  let entry = try? formReplyEntry(from: encoded) else {
                continue
            }
            table[entry.id] = entry.entry
        }
        return table
    }

    /// The reply table of one form.
    ///
    /// A form that arrives over the event stream is not in the polled list
    /// yet, so the poll cannot be the only source of the mapping from the
    /// labels the app shows to the values the server expects.
    static func formReplyEntry(from data: Data) throws -> (id: String, entry: FormReplyEntry) {
        let wire = try JSONDecoder().decode(V2Form.self, from: data)
        let fields = wire.fields.map { field in
            FormReplyEntry.Field(
                key: field.key,
                optionValues: (field.options ?? []).reduce(into: [:]) { values, option in
                    values[option.label] = option.value
                }
            )
        }
        return (wire.id, FormReplyEntry(sessionID: wire.sessionID, fields: fields))
    }

    // MARK: - Active sessions

    /// `GET /api/session/active` lists the busy sessions.
    static func activeSessionStatuses(from data: Data) throws -> [String: SessionStatus] {
        let payload = try unwrap(data)
        guard let rows = payload as? [String: Any] else { throw V2MappingError.malformed }
        var statuses: [String: SessionStatus] = [:]
        for (sessionID, value) in rows {
            guard let entry = value as? [String: Any] else { continue }
            let type = entry["type"] as? String
            statuses[sessionID] = SessionStatus(
                type: type == "running" ? "busy" : "idle",
                attempt: nil,
                message: nil,
                next: nil
            )
        }
        return statuses
    }

    // MARK: - Request bodies

    /// V2 prompts carry text, not parts. Images ride along as `files`.
    static func promptBody(text: String, files: [ComposerImageAttachment]) throws -> Data {
        try promptBody(text: text, files: files, messageID: nil)
    }

    static func promptBody(text: String, files: [ComposerImageAttachment], messageID: String?) throws -> Data {
        struct FileInput: Encodable {
            let uri: String
            let name: String
        }
        struct Body: Encodable {
            let text: String
            let files: [FileInput]?
            let id: String?
        }
        let body = Body(
            text: text,
            files: files.isEmpty ? nil : files.map { FileInput(uri: $0.dataURL, name: $0.filename) },
            id: messageID
        )
        return try JSONEncoder().encode(body)
    }

    /// The server's default model.
    static func defaultModel(from data: Data) throws -> (providerID: String, modelID: String)? {
        let payload = try unwrap(data)
        guard let dictionary = payload as? [String: Any] else { throw V2MappingError.malformed }
        guard let providerID = dictionary["providerID"] as? String,
              let modelID = (dictionary["id"] as? String) ?? (dictionary["modelID"] as? String) else {
            return nil
        }
        return (providerID, modelID)
    }

    /// `GET /api/vcs/status` lists the changed files.
    static func fileStatus(from data: Data) throws -> [FileStatusEntry] {
        let payload = try unwrap(data)
        guard let rows = payload as? [Any] else { throw V2MappingError.malformed }
        return rows.compactMap { row in
            guard let dictionary = row as? [String: Any] else { return nil }
            let path = (dictionary["file"] as? String) ?? (dictionary["path"] as? String)
            let status = dictionary["status"] as? String
            guard path != nil || status != nil else { return nil }
            return FileStatusEntry(path: path, status: status)
        }
    }

    /// V2 archives with a top-level boolean; the V1 `time.archived` body is
    /// silently ignored by the server.
    static func archiveBody(archived: Bool) throws -> Data {
        struct Body: Encodable {
            let archived: Bool
        }
        return try JSONEncoder().encode(Body(archived: archived))
    }

    /// V2 creates a session with its directory in `location`. Without it the
    /// server uses the server's current directory.
    static func createSessionBody(title: String?, directory: String?) throws -> Data {
        struct Location: Encodable {
            let directory: String
        }
        struct Body: Encodable {
            let title: String?
            let location: Location?
        }
        let trimmedDirectory = directory?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = Body(
            title: title,
            location: trimmedDirectory.flatMap { $0.isEmpty ? nil : Location(directory: $0) }
        )
        return try JSONEncoder().encode(body)
    }
}

enum V2MappingError: Error {
    case malformed
}

/// The label → value mapping a V2 form needs when it is replied to.
nonisolated struct FormReplyEntry {
    let sessionID: String
    let fields: [Field]

    struct Field {
        let key: String
        /// Label → value. Two options with the same label keep the first value.
        let optionValues: [String: String]
    }

    /// Translate the labels the app collected into the values the server
    /// expects. A label with no matching option is a custom answer.
    func values(for key: String, labels: [String]) -> [String] {
        guard let field = fields.first(where: { $0.key == key }) else {
            return labels
        }
        return labels.map { field.optionValues[$0] ?? $0 }
    }
}

// MARK: - Wire shapes

private struct V2Location: Decodable {
    let directory: String
}

private struct V2SessionTime: Decodable {
    let created: Int?
    let updated: Int?
    let archived: Int?
}

nonisolated private struct V2Session: Decodable {
    let id: String
    let projectID: String?
    let title: String?
    let location: V2Location?
    let parentID: String?
    let time: V2SessionTime?
    let tokens: Message.TokenInfo?
    let cost: Double?

    func session() -> Session {
        Session(
            id: id,
            slug: id,
            projectID: projectID ?? "",
            directory: location?.directory ?? "",
            parentID: parentID,
            title: title ?? "Untitled",
            version: "2",
            time: Session.TimeInfo(
                created: time?.created ?? 0,
                updated: time?.updated ?? 0,
                archived: time?.archived
            ),
            share: nil,
            summary: nil,
            tokens: tokens,
            cost: cost
        )
    }
}

private struct V2ModelRef: Decodable {
    let id: String
    let providerID: String
}

private struct V2Error: Decodable {
    let type: String?
    let message: String?
}

private struct V2MessageTime: Decodable {
    let created: Int
    let completed: Int?
}

private struct V2FileAttachment: Decodable {
    let data: String
    let mime: String
    let name: String?
}

private struct V2Content: Decodable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let state: V2ToolState?

    struct V2ToolState: Decodable {
        let status: String
        let input: [String: AnyCodable]?
        let content: [V2ToolContent]?
        let error: V2Error?
        let metadata: [String: AnyCodable]?

        struct V2ToolContent: Decodable {
            let type: String
            let text: String?
        }
    }
}

private struct V2Snapshot: Decodable {
    let start: String?
    let end: String?
    /// The relative paths this step changed. Paths only — no counts.
    let files: [String]?
}

nonisolated private struct V2Message: Decodable {
    let id: String
    let type: String
    let text: String?
    let files: [V2FileAttachment]?
    let content: [V2Content]?
    let model: V2ModelRef?
    let agent: String?
    let error: V2Error?
    let finish: String?
    let tokens: Message.TokenInfo?
    let cost: Double?
    let time: V2MessageTime
    let snapshot: V2Snapshot?

    func message(sessionID: String, parentID: String?) -> MessageWithParts {
        let info = Message(
            id: id,
            sessionID: sessionID,
            role: type,
            parentID: parentID,
            providerID: model?.providerID,
            modelID: model?.id,
            model: model.map { Message.ModelInfo(providerID: $0.providerID, modelID: $0.id) },
            error: error.map { Message.MessageError(name: $0.type ?? "error", data: ["message": .init($0.message ?? "")]) },
            time: Message.TimeInfo(created: time.created, completed: time.completed),
            finish: finish,
            tokens: tokens,
            cost: cost,
            agent: agent
        )
        return MessageWithParts(info: info, parts: parts(sessionID: sessionID))
    }

    private func parts(sessionID: String) -> [Part] {
        if type == "user" {
            var parts: [Part] = []
            if let text, !text.isEmpty {
                parts.append(Part(
                    id: "\(id)-text-0",
                    messageID: id,
                    sessionID: sessionID,
                    type: "text",
                    text: text,
                    tool: nil,
                    callID: nil,
                    state: nil,
                    metadata: nil,
                    files: nil
                ))
            }
            for (index, file) in (files ?? []).enumerated() {
                parts.append(Part(
                    id: "\(id)-file-\(index)",
                    messageID: id,
                    sessionID: sessionID,
                    type: "file",
                    text: nil,
                    tool: nil,
                    callID: nil,
                    state: nil,
                    metadata: nil,
                    files: nil,
                    mime: file.mime,
                    filename: file.name,
                    url: "data:\(file.mime);base64,\(file.data)"
                ))
            }
            return parts
        }

        var parts: [Part] = []
        // V2 counts the ordinals per part type, and the SSE stream numbers
        // them the same way. The REST snapshot and the live stream must build
        // the same part id, or one call renders as two cards.
        var textOrdinal = 0
        var reasoningOrdinal = 0
        for (index, entry) in (content ?? []).enumerated() {
            switch entry.type {
            case "text":
                parts.append(Part(
                    id: "\(id)-text-\(textOrdinal)",
                    messageID: id,
                    sessionID: sessionID,
                    type: "text",
                    text: entry.text,
                    tool: nil,
                    callID: nil,
                    state: nil,
                    metadata: nil,
                    files: nil
                ))
                textOrdinal += 1
            case "reasoning":
                parts.append(Part(
                    id: "\(id)-reasoning-\(reasoningOrdinal)",
                    messageID: id,
                    sessionID: sessionID,
                    type: "reasoning",
                    text: entry.text,
                    tool: nil,
                    callID: nil,
                    state: nil,
                    metadata: nil,
                    files: nil
                ))
                reasoningOrdinal += 1
            case "tool":
                parts.append(Part(
                    id: V2EventTranslator.toolPartID(messageID: id, callID: entry.id ?? String(index)),
                    messageID: id,
                    sessionID: sessionID,
                    type: "tool",
                    text: nil,
                    tool: entry.name,
                    callID: entry.id,
                    state: entry.state.flatMap { $0.bridge() },
                    metadata: nil,
                    files: nil
                ))
            default:
                continue
            }
        }
        // V2 has no patch part: the paths a step changed live on the message's
        // snapshot. Synthesize the same part shape V1 sends so one renderer
        // serves both generations.
        if let changed = snapshot?.files, !changed.isEmpty {
            parts.append(Part(
                id: "\(id)-patch-0",
                messageID: id,
                sessionID: sessionID,
                type: "patch",
                text: nil,
                tool: nil,
                callID: nil,
                state: nil,
                metadata: nil,
                files: changed.map { Part.FileChange(path: $0) }
            ))
        }
        return parts
    }
}

nonisolated private extension V2Content.V2ToolState {
    /// Normalize the V2 tool state into the shape `PartStateBridge` reads:
    /// V2 puts the output in a `content` array, V1 in an `output` string.
    func bridge() -> PartStateBridge? {
        var normalized: [String: Any] = ["status": status]
        if let input {
            normalized["input"] = input.mapValues(\.value)
        }
        let outputText = (content ?? [])
            .compactMap { $0.text }
            .joined(separator: "\n")
        if !outputText.isEmpty {
            normalized["output"] = outputText
        }
        if let metadata {
            normalized["metadata"] = metadata.mapValues(\.value)
        }
        if let error {
            normalized["error"] = error.message ?? error.type
        }
        guard let data = try? JSONSerialization.data(withJSONObject: normalized) else { return nil }
        return try? JSONDecoder().decode(PartStateBridge.self, from: data)
    }
}

nonisolated private struct V2Provider: Decodable {
    let id: String
    let name: String?
    let activation: String?
}

nonisolated private struct V2Model: Decodable {
    let id: String
    let modelID: String?
    let providerID: String
    let name: String?
    let family: String?
    let limit: V2ModelLimit?
    let capabilities: V2ModelCapabilities?

    struct V2ModelLimit: Decodable {
        let context: Int?
        let output: Int?
    }

    struct V2ModelCapabilities: Decodable {
        let tools: Bool?
        let input: [String]?
        let output: [String]?
    }

    func model() -> ProviderModel {
        ProviderModel(
            id: id,
            name: name,
            providerID: providerID,
            limit: limit.map { ProviderModelLimit(context: $0.context, input: nil, output: $0.output) },
            capabilities: capabilities.map {
                ProviderModelCapabilities(
                    reasoning: nil,
                    toolCall: $0.tools,
                    attachment: $0.input?.contains("image") == true,
                    input: nil,
                    output: nil
                )
            },
            family: family
        )
    }
}

nonisolated private struct V2Agent: Decodable {
    let id: String
    let name: String?
    let description: String?
    let mode: String?
    let hidden: Bool?
}

nonisolated private struct V2FileNode: Decodable {
    let path: String
    let type: String
}

nonisolated private struct V2Diff: Decodable {
    let file: String
    let patch: String
    let additions: Int?
    let deletions: Int?
    let status: String?
}

private struct V2ProjectTime: Decodable {
    let created: Int?
    let updated: Int?
}

nonisolated private struct V2Project: Decodable {
    let id: String
    let canonical: String
    let vcs: String?
    let time: V2ProjectTime?
}

private struct V2PermissionSource: Decodable {
    let messageID: String?
    let id: String?
}

nonisolated private struct V2Permission: Decodable {
    let id: String
    let sessionID: String
    let action: String
    let resources: [String]?
    let source: V2PermissionSource?
}

private struct V2FormOption: Decodable {
    let value: String
    let label: String
    let description: String?
}

private struct V2FormField: Decodable {
    let key: String
    let type: String
    let title: String?
    let options: [V2FormOption]?
}

nonisolated private struct V2Form: Decodable {
    let id: String
    let sessionID: String
    let title: String?
    let fields: [V2FormField]
}
