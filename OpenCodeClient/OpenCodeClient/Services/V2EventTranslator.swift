import Foundation

/// Translates OpenCode V2 SSE frames into the app's V1 event shapes.
///
/// V2 publishes `{"id":…,"type":…,"data":…}` frames with its own event names.
/// The app's SSE handlers already know the V1 names and property shapes, so
/// the translation happens here: the handler code stays unchanged and the
/// MessageStore keeps seeing the parts it expects.
///
/// The translator is stateful. V2 splits one tool call over six frames
/// (`input.started`, `input.ended`, `called`, `progress`, `success`,
/// `failed`), while the app renders one card per call. So the translator
/// keeps the state of every call it has seen and re-emits the whole call on
/// each frame: the frame that says "running" carries the name and the input
/// the earlier frames delivered. One instance belongs to one connection.
///
/// Event names measured against upstream `v2.1.3`; see
/// `docs/features/v2_support/plan.md`.
nonisolated struct V2EventTranslator {
    /// A V2 frame.
    struct Frame: Decodable {
        let id: String?
        let type: String
        let data: [String: AnyCodable]?

        /// The frame data as plain values.
        var values: [String: Any] {
            (data ?? [:]).mapValues(\.value)
        }
    }

    /// What the app knows about one tool call so far.
    private struct ToolCall {
        var sessionID: String = ""
        var messageID: String = ""
        var callID: String = ""
        var name: String?
        var input: [String: Any]?
        /// The raw argument text, kept when the arguments are not a JSON
        /// object (V1 puts a plain string in `state.input`).
        var inputText: String?
        var output: String?
        var error: String?
        var metadata: [String: Any]?
        var status: String = ToolStatus.pending
    }

    /// The tool vocabulary the app renders. V2 reports the lifecycle in its
    /// own words; the card and the composer know the V1 ones.
    private enum ToolStatus {
        static let pending = "pending"
        static let running = "running"
        static let completed = "completed"
        static let error = "error"
    }

    /// A status the call does not come back from.
    private static func isTerminalStatus(_ status: String) -> Bool {
        status == ToolStatus.completed || status == ToolStatus.error
    }

    /// The tool calls this connection has seen, keyed by the server's call id.
    private var toolCalls: [String: ToolCall] = [:]
    /// The order the calls came in, so the oldest can be dropped.
    private var toolCallOrder: [String] = []
    /// How many calls one connection keeps in memory. A long session runs many
    /// tool calls; keeping all of them would grow the translator forever.
    private static let maxTrackedToolCalls = 64

    /// Translate one V2 frame. Returns `nil` for a frame the app ignores.
    mutating func translate(_ frame: Frame) -> SSEEvent? {
        let data = frame.values
        switch frame.type {
        case "server.connected":
            return Self.event(type: "server.connected", properties: [:])

        case "session.status":
            // `data` already carries `sessionID` and `status`.
            return Self.event(type: "session.status", properties: data)

        case "session.idle":
            return Self.event(
                type: "session.status",
                properties: [
                    "sessionID": data["sessionID"] as Any,
                    "status": ["type": "idle"],
                ]
            )

        case "session.created", "session.renamed", "session.metadata.updated":
            // V2 does not send the session body: the app reads it back.
            return Self.event(
                type: "session.updated",
                properties: [
                    "sessionID": data["sessionID"] as Any,
                    "v2Refresh": true,
                ]
            )

        case "session.deleted":
            return Self.event(type: "session.deleted", properties: data)

        case "session.text.started":
            guard let part = Self.textPart(data, text: nil) else { return nil }
            return Self.event(
                type: "message.part.updated",
                properties: [
                    "sessionID": data["sessionID"] as Any,
                    "messageID": data["assistantMessageID"] as Any,
                    "part": part,
                ]
            )

        case "session.text.delta":
            guard let partID = Self.textPartID(data) else { return nil }
            return Self.event(
                type: "message.part.delta",
                properties: [
                    "sessionID": data["sessionID"] as Any,
                    "messageID": data["assistantMessageID"] as Any,
                    "partID": partID,
                    "field": "text",
                    "delta": data["delta"] as Any,
                ]
            )

        case "session.text.ended":
            guard let part = Self.textPart(data, text: data["text"] as? String) else { return nil }
            return Self.event(
                type: "message.part.updated",
                properties: [
                    "sessionID": data["sessionID"] as Any,
                    "messageID": data["assistantMessageID"] as Any,
                    "part": part,
                ]
            )

        case "session.tool.input.started", "session.tool.input.ended":
            // The arguments are still streaming: the call exists, it does not
            // run yet.
            return toolEvent(data, status: ToolStatus.pending)

        case "session.tool.called", "session.tool.progress":
            return toolEvent(data, status: ToolStatus.running)

        case "session.tool.success":
            return toolEvent(data, status: ToolStatus.completed)

        case "session.tool.failed":
            return toolEvent(data, status: ToolStatus.error)

        case "session.reasoning.ended", "session.message.content.updated":
            // No part of its own: the app reloads the transcript.
            return Self.event(type: "message.updated", properties: [:])

        case "permission.asked":
            return Self.event(type: "permission.asked", properties: Self.permissionProperties(data))

        case "permission.replied":
            return Self.event(type: "permission.replied", properties: data)

        case "form.created":
            guard let form = data["form"] as? [String: Any] else { return nil }
            return Self.event(type: "question.asked", properties: Self.formProperties(form))

        case "form.replied", "form.cancelled":
            return Self.event(
                type: "question.rejected",
                properties: ["id": data["id"] as Any]
            )

        case "session.execution.failed":
            let error = data["error"] as? [String: Any] ?? [:]
            return Self.event(
                type: "session.error",
                properties: [
                    "sessionID": data["sessionID"] as Any,
                    "error": [
                        "name": error["type"] as Any,
                        "data": ["message": error["message"] as Any],
                    ],
                ]
            )

        default:
            // `session.reasoning.delta` and every other event the app does
            // not render.
            return nil
        }
    }

    // MARK: - Tool calls

    /// The part id of a tool call. The SSE path and the REST path must build
    /// the same id, or the same call renders as two cards.
    static func toolPartID(messageID: String, callID: String) -> String {
        "\(messageID)-tool-\(callID)"
    }

    /// Applies one `session.tool.*` frame to the call it belongs to and
    /// returns the call as a V1-shaped tool part.
    private mutating func toolEvent(_ data: [String: Any], status: String) -> SSEEvent? {
        guard let callID = data["id"] as? String, !callID.isEmpty else { return nil }
        var call = toolCalls[callID] ?? ToolCall(callID: callID)
        if let sessionID = data["sessionID"] as? String { call.sessionID = sessionID }
        if let messageID = data["assistantMessageID"] as? String { call.messageID = messageID }
        if let name = data["name"] as? String, !name.isEmpty { call.name = name }
        // A late frame must not reopen a call the server already closed.
        if !Self.isTerminalStatus(call.status) || Self.isTerminalStatus(status) {
            call.status = status
        }

        if let input = Self.dictionary(data["input"]) {
            call.input = input
        } else if let text = data["text"] as? String {
            // `input.ended` carries the arguments as raw JSON text.
            call.inputText = text
            if let parsed = Self.decodeJSONObject(text) { call.input = parsed }
        }
        if let metadata = Self.dictionary(data["metadata"]) {
            call.metadata = (call.metadata ?? [:]).merging(metadata) { _, new in new }
        }
        if let content = Self.array(data["content"]) {
            let text = content
                .compactMap { element -> String? in
                    guard let dict = Self.dictionary(element) else { return nil }
                    return dict["text"] as? String
                }
                .joined(separator: "\n")
            if !text.isEmpty { call.output = text }
        }
        if let error = Self.dictionary(data["error"]) {
            call.error = (error["message"] as? String) ?? (error["type"] as? String)
        }

        remember(call)
        return toolPartEvent(call)
    }

    /// The tool part the app's `message.part.updated` handler expects: one
    /// part per call, carrying the whole state of that call.
    private func toolPartEvent(_ call: ToolCall) -> SSEEvent? {
        guard !call.messageID.isEmpty, !call.sessionID.isEmpty else { return nil }
        var state: [String: Any] = ["status": call.status]
        if let input = call.input {
            state["input"] = input
        } else if let text = call.inputText {
            state["input"] = text
        }
        if let output = call.output { state["output"] = output }
        if let error = call.error { state["error"] = error }
        if let metadata = call.metadata { state["metadata"] = metadata }

        var part: [String: Any] = [
            "type": "tool",
            "id": Self.toolPartID(messageID: call.messageID, callID: call.callID),
            "messageID": call.messageID,
            "sessionID": call.sessionID,
            "callID": call.callID,
            "state": state,
        ]
        if let name = call.name { part["tool"] = name }
        return Self.event(
            type: "message.part.updated",
            properties: [
                "sessionID": call.sessionID,
                "messageID": call.messageID,
                "part": part,
            ]
        )
    }

    /// Keeps the call state, and drops the oldest call once the connection
    /// tracked too many.
    private mutating func remember(_ call: ToolCall) {
        if toolCalls[call.callID] == nil {
            toolCallOrder.append(call.callID)
        }
        toolCalls[call.callID] = call
        while toolCallOrder.count > Self.maxTrackedToolCalls {
            let oldest = toolCallOrder.removeFirst()
            toolCalls[oldest] = nil
        }
    }

    // MARK: - Helpers

    private static func event(type: String, properties: [String: Any]) -> SSEEvent {
        let wrapped = properties.mapValues { AnyCodable($0) }
        return SSEEvent(directory: nil, payload: SSEPayload(type: type, properties: wrapped))
    }

    /// The part id for a text part: the assistant message id plus the ordinal.
    /// The same ordinal always yields the same id, including after a
    /// reconnect.
    private static func textPartID(_ data: [String: Any]) -> String? {
        guard let messageID = data["assistantMessageID"] as? String else { return nil }
        guard let ordinal = data["ordinal"] as? Int else { return nil }
        return "\(messageID)-text-\(ordinal)"
    }

    private static func textPart(_ data: [String: Any], text: String?) -> [String: Any]? {
        guard let partID = Self.textPartID(data),
              let messageID = data["assistantMessageID"] as? String else {
            return nil
        }
        var part: [String: Any] = [
            "type": "text",
            "id": partID,
            "messageID": messageID,
        ]
        if let sessionID = data["sessionID"] as? String {
            part["sessionID"] = sessionID
        }
        if let text {
            part["text"] = text
        }
        return part
    }

    /// V2 names the permission `action` and its targets `resources`; the app
    /// expects `permission` and `patterns`.
    private static func permissionProperties(_ data: [String: Any]) -> [String: Any] {
        var properties: [String: Any] = data
        if let action = data["action"] as? String {
            properties["permission"] = action
        }
        if let resources = data["resources"] as? [String] {
            properties["patterns"] = resources
        }
        if let source = data["source"] as? [String: Any] {
            var tool: [String: Any] = [:]
            if let messageID = source["messageID"] as? String { tool["messageID"] = messageID }
            if let callID = source["id"] as? String { tool["callID"] = callID }
            properties["tool"] = tool
        }
        return properties
    }

    /// A V2 form becomes the app's question request shape.
    private static func formProperties(_ form: [String: Any]) -> [String: Any] {
        var properties: [String: Any] = form
        guard let fields = form["fields"] as? [[String: Any]] else { return properties }
        let questions = fields.compactMap { field -> [String: Any]? in
            guard let key = field["key"] as? String else { return nil }
            let options = (field["options"] as? [[String: Any]] ?? []).map { option in
                [
                    // A V2 option may carry no description. The app's option
                    // has one, and a null would fail the whole question's
                    // decoding — the card would never appear.
                    "label": (option["label"] as? String) ?? "",
                    "description": (option["description"] as? String) ?? "",
                ]
            }
            var question: [String: Any] = [
                "question": (field["title"] as? String) ?? key,
                "header": key,
                "options": options,
            ]
            if field["type"] as? String == "multiselect" {
                question["multiple"] = true
            }
            return question
        }
        properties["questions"] = questions
        return properties
    }

    /// A JSON object as plain values, or nil when the value is not one.
    static func dictionary(_ value: Any?) -> [String: Any]? {
        if let dict = value as? [String: Any] { return dict }
        if let dict = value as? [String: AnyCodable] { return dict.mapValues(\.value) }
        return nil
    }

    /// A JSON array as plain values, or nil when the value is not one.
    static func array(_ value: Any?) -> [Any]? {
        if let array = value as? [Any] { return array }
        return nil
    }

    /// The arguments of a tool call, as sent in `input.ended`.
    private static func decodeJSONObject(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any] else {
            return nil
        }
        return dict
    }
}
