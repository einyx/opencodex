//
//  APIClient.swift
//  OpenCodeClient
//

import Foundation
import os

nonisolated struct MessageTranscriptDecode: Sendable {
    let messages: [MessageWithParts]
    let diagnostics: [WireDecodeDiagnostic]
}

nonisolated enum MessageTranscriptError: Error, Equatable {
    case invalidJSON
    case unsupportedShape
    case noneDecoded(diagnostics: [WireDecodeDiagnostic])
}

actor APIClient {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "OpenCodeClient",
        category: "APIClient"
    )

    private var baseURL: String
    private var username: String?
    private var password: String?
    private let session: URLSession

    /// Which OpenCode API this client speaks. `.auto` probes on the first
    /// request; the result is remembered for the life of the client.
    private var generation: ServerGeneration = .auto
    /// Sessions this client has seen. V2 lists permissions and questions per
    /// session, so the global refresh walks them.
    private var knownSessionIDs: Set<String> = []
    /// V2 forms are replied to with option *values*, not the labels the app
    /// collects. The table is filled when the forms are read.
    private var formReplyTable: [String: FormReplyEntry] = [:]

    // Default to localhost to avoid leaking a personal LAN IP in open source repos.
    nonisolated static let defaultServer = "127.0.0.1:4096"

    init(
        baseURL: String = APIClient.defaultServer,
        username: String? = nil,
        password: String? = nil,
        session: URLSession = APIClient.makeDefaultSession(),
        generation: ServerGeneration = .auto
    ) {
        self.baseURL = Self.normalizeBaseURL(baseURL)
        self.username = username
        self.password = password
        self.session = session
        self.generation = generation
    }

    /// The session the app's own requests use.
    ///
    /// `waitsForConnectivity` is off on purpose. A request to a host that
    /// cannot be reached has to fail and be reported, not sit in the
    /// background waiting for a network that may never come: with it on, a
    /// connection check to an unreachable server stayed in "Checking…"
    /// for as long as the device had no route to it, while the status row
    /// still showed the version of the last good connection.
    ///
    /// The resource timeout bounds a response that keeps trickling bytes
    /// without ever finishing.
    nonisolated static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }

    func configure(baseURL: String, username: String? = nil, password: String? = nil) {
        configure(baseURL: baseURL, username: username, password: password, generation: generation)
    }

    func configure(
        baseURL: String,
        username: String? = nil,
        password: String? = nil,
        generation: ServerGeneration
    ) {
        let normalized = Self.normalizeBaseURL(baseURL)
        let addressChanged = normalized != self.baseURL
        self.baseURL = normalized
        self.username = username
        self.password = password
        if addressChanged {
            // The generation belongs to the address: a different server has
            // to be probed again.
            self.generation = .auto
            knownSessionIDs.removeAll()
            formReplyTable.removeAll()
        } else if generation != .auto {
            self.generation = generation
        }
    }

    /// The generation this client currently speaks.
    func currentGeneration() -> ServerGeneration {
        generation
    }

    /// A separate gate and cancellable session, using the same phone-only route.
    func makeWatchClient() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        // The watch talks to the same server, so it speaks the same API.
        return APIClient(baseURL: baseURL, username: username, password: password,
                         session: URLSession(configuration: config),
                         generation: generation)
    }

    nonisolated func cancelWatchRequests() {
        session.invalidateAndCancel()
    }

    /// Adds http:// when no scheme is present and strips trailing slashes so
    /// appended paths (e.g. "/global/health") never produce double slashes.
    nonisolated static func normalizeBaseURL(_ raw: String) -> String {
        var base = raw.hasPrefix("http") ? raw : "http://\(raw)"
        while base.hasSuffix("/"), base.count > 8 {
            base.removeLast()
        }
        return base
    }

    private func makeRequest(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil,
        liveToken: UInt64? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let url: URL
        if let queryItems {
            guard var components = URLComponents(string: "\(baseURL)\(path)") else {
                throw APIError.invalidURL
            }
            components.queryItems = queryItems
            guard let built = components.url else {
                throw APIError.invalidURL
            }
            url = built
        } else {
            guard let built = URL(string: "\(baseURL)\(path)") else {
                throw APIError.invalidURL
            }
            url = built
        }

        guard url.scheme != nil else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyCredentials(to: &request)

        if let body {
            request.httpBody = body
        }
        if let liveToken {
            try ensureLiveTransport(liveToken)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.httpError(statusCode: 0, data: data)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(statusCode: http.statusCode, data: data)
        }
        return (data, http)
    }

    private func applyCredentials(to request: inout URLRequest) {
        guard let username, let password else { return }
        let credential = "\(username):\(password)"
        guard let data = credential.data(using: .utf8) else { return }
        request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
    }

    /// A request that reports the status instead of throwing on it. The
    /// generation probe needs to see a `401` and an HTML body.
    private func probe(path: String, accept: String = "application/json") async throws -> (status: Int, body: Data) {
        guard let built = URL(string: "\(baseURL)\(path)") else { throw APIError.invalidURL }
        var request = URLRequest(url: built)
        request.setValue(accept, forHTTPHeaderField: "Accept")
        applyCredentials(to: &request)
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (status, data)
    }

    /// Probe which OpenCode API the host speaks.
    ///
    /// `/global/health` decides V1: it answers with JSON there and with the
    /// SPA shell on a V2 server. Only when it is not V1 is `/api/info` tried,
    /// which is the V2 marker. A `401` or `403` is an authentication failure
    /// and never falls through to the other probe.
    ///
    /// The result is remembered: the probe runs once per host, not once per
    /// request. An unrecognised server leaves the generation unset, so the
    /// caller keeps the V1 behaviour and reports the real error itself.
    func detectGeneration() async throws -> ServerGeneration {
        let health = try await probe(path: "/global/health")
        if health.status == 401 || health.status == 403 {
            throw APIError.httpError(statusCode: health.status, data: health.body)
        }
        switch ServerGenerationProbe.classify(healthStatus: health.status, healthBody: health.body) {
        case .v1:
            generation = .v1
            return .v1
        default:
            break
        }
        let info = try await probe(path: "/api/info")
        if info.status == 401 || info.status == 403 {
            throw APIError.httpError(statusCode: info.status, data: info.body)
        }
        let detected = ServerGenerationProbe.classify(infoStatus: info.status, infoBody: info.body)
        guard detected == .v2 else { throw APIError.unsupportedServer }
        generation = .v2
        return .v2
    }

    /// The generation requests are routed with.
    ///
    /// An unknown generation means the host was never probed: the client keeps
    /// its historical V1 behaviour, and the health check reports the problem.
    private func resolvedGeneration() async throws -> ServerGeneration {
        switch generation {
        case .v1, .v2:
            return generation
        case .auto, .unrecognized:
            return .v1
        }
    }

    private func acceptEmptyOrJSONBoolean(_ data: Data) throws {
        if let text = String(data: data, encoding: .utf8),
           text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        _ = try JSONDecoder().decode(Bool.self, from: data)
    }

    func health() async throws -> HealthResponse {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            let (data, _) = try await makeRequest(path: "/api/info")
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            return HealthResponse(healthy: true, version: object?["version"] as? String)
        }
        let (data, _) = try await makeRequest(path: "/global/health")
        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }

    func projects() async throws -> [Project] {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            let (data, _) = try await makeRequest(path: "/api/project")
            return try V2Mapper.projects(from: data)
        }
        let (data, _) = try await makeRequest(path: "/project")
        return try JSONDecoder().decode([Project].self, from: data)
    }

    func projectCurrent() async throws -> Project? {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            let (data, _) = try await makeRequest(path: "/api/location")
            return try V2Mapper.currentProject(from: data)
        }
        let (data, _) = try await makeRequest(path: "/project/current")
        return try? JSONDecoder().decode(Project.self, from: data)
    }

    func sessions(directory: String? = nil, limit: Int = 100) async throws -> [Session] {
        let generation = try await resolvedGeneration()
        var queryItems: [URLQueryItem] = []
        if let directory, !directory.isEmpty {
            queryItems.append(URLQueryItem(name: "directory", value: directory))
        }
        if limit > 0 {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if generation == .v2 {
            let (data, _) = try await makeRequest(
                path: "/api/session",
                queryItems: queryItems.isEmpty ? nil : queryItems
            )
            let sessions = try V2Mapper.sessions(from: data)
            rememberSessions(sessions)
            return sessions
        }
        let (data, _) = try await makeRequest(
            path: "/session",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
        let sessions = try JSONDecoder().decode([Session].self, from: data)
        rememberSessions(sessions)
        return sessions
    }

    /// Sessions this client has seen. V2 lists permissions and questions per
    /// session, so the global refresh walks them.
    private func rememberSessions(_ sessions: [Session]) {
        for session in sessions {
            knownSessionIDs.insert(session.id)
        }
    }

    func session(sessionID: String) async throws -> Session {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            let (data, _) = try await makeRequest(path: "/api/session/\(sessionID)")
            let session = try V2Mapper.session(from: data)
            knownSessionIDs.insert(session.id)
            return session
        }
        let (data, _) = try await makeRequest(path: "/session/\(sessionID)")
        return try JSONDecoder().decode(Session.self, from: data)
    }

    func promptStructured(
        sessionID: String,
        messageID: String? = nil,
        text: String,
        system: String,
        format: StructuredOutputFormat,
        agent: String = "build",
        model: Message.ModelInfo
    ) async throws -> MessageWithParts {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            return try await promptStructuredV2(
                sessionID: sessionID,
                messageID: messageID,
                text: text,
                system: system,
                format: format,
                agent: agent,
                model: model
            )
        }
        struct PromptBody: Encodable {
            struct PartInput: Encodable {
                let type: String
                let text: String
            }

            struct ModelInput: Encodable {
                let providerID: String
                let modelID: String
            }

            let parts: [PartInput]
            let messageID: String?
            let system: String
            let format: StructuredOutputFormat
            let agent: String
            let model: ModelInput
        }

        let body = PromptBody(
            parts: [.init(type: "text", text: text)],
            messageID: messageID,
            system: system,
            format: format,
            agent: agent,
            model: .init(providerID: model.providerID, modelID: model.modelID)
        )
        let bodyData = try JSONEncoder().encode(body)
        let (responseData, _) = try await makeRequest(
            path: "/session/\(sessionID)/message",
            method: "POST",
            body: bodyData
        )
        return try JSONDecoder().decode(MessageWithParts.self, from: responseData)
    }

    /// V2 has no structured-output field: the schema goes into the prompt and
    /// the assistant's text is parsed locally.
    private func promptStructuredV2(
        sessionID: String,
        messageID: String?,
        text: String,
        system: String,
        format: StructuredOutputFormat,
        agent: String,
        model: Message.ModelInfo
    ) async throws -> MessageWithParts {
        try await switchAgentAndModelV2(sessionID: sessionID, agent: agent, model: model)

        let schema = (try? JSONEncoder().encode(format)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let prompt = [
            system,
            "",
            text,
            "",
            "Reply with only JSON matching this schema:",
            schema,
        ].joined(separator: "\n")

        let admittedID = messageID ?? "msg_v2_\(UUID().uuidString)"
        let body = try V2Mapper.promptBody(text: prompt, files: [], messageID: admittedID)
        let (_, http) = try await makeRequest(
            path: "/api/session/\(sessionID)/prompt",
            method: "POST",
            body: body
        )
        guard http.statusCode == 200 else {
            throw APIError.httpError(statusCode: http.statusCode, data: Data())
        }

        // The server does not enforce the schema, so the answer is parsed
        // here. Poll the transcript until the assistant answered.
        for _ in 0..<60 {
            try await Task.sleep(for: .seconds(1))
            let (data, _) = try await makeRequest(path: "/api/session/\(sessionID)/message", queryItems: [
                URLQueryItem(name: "limit", value: "50")
            ])
            let messages = try V2Mapper.messages(from: data, sessionID: sessionID)
            guard let answer = messages.last(where: { $0.info.role == "assistant" }) else { continue }
            let answerText = answer.parts
                .filter { $0.type == "text" }
                .compactMap(\.text)
                .joined(separator: "\n")
            guard !answerText.isEmpty else { continue }
            guard let json = try? JSONDecoder().decode(WireJSON.self, from: Data(answerText.utf8)),
                  let envelope = try? CarResponseEnvelope(validating: json),
                  envelope.version == 1,
                  !envelope.speech.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CarModeError.invalidResponse
            }
            var info = answer.info
            if info.time.completed == nil {
                info = Message(
                    id: info.id,
                    sessionID: info.sessionID,
                    role: info.role,
                    parentID: info.parentID,
                    providerID: info.providerID,
                    modelID: info.modelID,
                    model: info.model,
                    error: info.error,
                    time: Message.TimeInfo(created: info.time.created, completed: info.time.created),
                    finish: info.finish,
                    tokens: info.tokens,
                    cost: info.cost,
                    structured: try WireJSON(encoding: envelope),
                    agent: info.agent
                )
            }
            return MessageWithParts(info: info, parts: answer.parts)
        }
        throw CarModeError.invalidResponse
    }

    /// Switch the session's agent and model. V2 keeps them out of the prompt
    /// body, on their own routes.
    private func switchAgentAndModelV2(
        sessionID: String,
        agent: String,
        model: Message.ModelInfo?,
        transportToken: UInt64? = nil
    ) async throws {
        let trimmedAgent = agent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAgent.isEmpty {
            struct AgentBody: Encodable {
                let agent: String
            }
            let data = try JSONEncoder().encode(AgentBody(agent: trimmedAgent))
            let (_, http) = try await makeRequest(
                path: "/api/session/\(sessionID)/agent",
                method: "POST",
                body: data,
                liveToken: transportToken
            )
            guard http.statusCode == 204 else {
                throw APIError.httpError(statusCode: http.statusCode, data: Data())
            }
        }
        if let model {
            struct ModelInput: Encodable {
                let id: String
                let providerID: String
            }
            struct ModelBody: Encodable {
                let model: ModelInput
            }
            let data = try JSONEncoder().encode(
                ModelBody(model: ModelInput(id: model.modelID, providerID: model.providerID))
            )
            let (_, http) = try await makeRequest(
                path: "/api/session/\(sessionID)/model",
                method: "POST",
                body: data,
                liveToken: transportToken
            )
            guard http.statusCode == 204 else {
                throw APIError.httpError(statusCode: http.statusCode, data: Data())
            }
        }
    }

    func createSession(title: String? = nil, directory: String? = nil) async throws -> Session {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            let body = try V2Mapper.createSessionBody(title: title, directory: directory)
            let (responseData, _) = try await makeRequest(path: "/api/session", method: "POST", body: body)
            let session = try V2Mapper.session(from: responseData)
            knownSessionIDs.insert(session.id)
            return session
        }
        let data = try JSONEncoder().encode(title.map { ["title": $0] } ?? [:])
        let queryItems = directory.map { [URLQueryItem(name: "directory", value: $0)] }
        let (responseData, _) = try await makeRequest(
            path: "/session",
            method: "POST",
            queryItems: queryItems,
            body: data
        )
        return try JSONDecoder().decode(Session.self, from: responseData)
    }

    func updateSession(sessionID: String, title: String) async throws -> Session {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            // V2 answers a title patch with `204` and no body: read it back.
            let body = try JSONEncoder().encode(["title": title])
            let (_, http) = try await makeRequest(path: "/api/session/\(sessionID)", method: "PATCH", body: body)
            guard http.statusCode == 204 else {
                throw APIError.httpError(statusCode: http.statusCode, data: Data())
            }
            return try await session(sessionID: sessionID)
        }
        let body = ["title": title]
        let data = try JSONEncoder().encode(body)
        let (responseData, _) = try await makeRequest(path: "/session/\(sessionID)", method: "PATCH", body: data)
        return try JSONDecoder().decode(Session.self, from: responseData)
    }

    func updateSessionArchived(sessionID: String, archived: Int) async throws -> Session {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            let data = try V2Mapper.archiveBody(archived: archived != 0)
            let (_, http) = try await makeRequest(path: "/api/session/\(sessionID)", method: "PATCH", body: data)
            guard http.statusCode == 204 else {
                throw APIError.httpError(statusCode: http.statusCode, data: Data())
            }
            return try await session(sessionID: sessionID)
        }
        struct ArchiveBody: Encodable {
            struct Time: Encodable { let archived: Int }
            let time: Time
        }
        let data = try JSONEncoder().encode(ArchiveBody(time: .init(archived: archived)))
        let (responseData, _) = try await makeRequest(path: "/session/\(sessionID)", method: "PATCH", body: data)
        return try JSONDecoder().decode(Session.self, from: responseData)
    }


    func deleteSession(sessionID: String) async throws {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            let (data, http) = try await makeRequest(path: "/api/session/\(sessionID)", method: "DELETE")
            guard http.statusCode == 204 else {
                throw APIError.httpError(statusCode: http.statusCode, data: data)
            }
            knownSessionIDs.remove(sessionID)
            return
        }
        let (data, _) = try await makeRequest(path: "/session/\(sessionID)", method: "DELETE")
        try acceptEmptyOrJSONBoolean(data)
    }

    func messages(sessionID: String, limit: Int? = nil) async throws -> [MessageWithParts] {
        let generation = try await resolvedGeneration()
        let queryItems: [URLQueryItem]? = {
            guard let limit, limit > 0 else { return nil }
            return [URLQueryItem(name: "limit", value: String(limit))]
        }()
        if generation == .v2 {
            // V2 serves the newest messages first and only accepts `order`
            // on the first page, so ask for `desc` and let the mapper put the
            // transcript back in chronological order.
            var v2QueryItems = queryItems ?? []
            v2QueryItems.append(URLQueryItem(name: "order", value: "desc"))
            let (data, _) = try await makeRequest(path: "/api/session/\(sessionID)/message", queryItems: v2QueryItems)
            return try V2Mapper.messages(from: data, sessionID: sessionID)
        }
        let (data, _) = try await makeRequest(path: "/session/\(sessionID)/message", queryItems: queryItems)
        guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return []
        }
        let payloadData = text.data(using: .utf8) ?? data
        let decoded = try Self.decodeMessageTranscript(payloadData)
        Self.logMessageDecodeDiagnostics(decoded.diagnostics)
        return decoded.messages
    }

    nonisolated static func decodeMessageTranscript(_ data: Data) throws -> MessageTranscriptDecode {
        if let direct = try? JSONDecoder().decode([MessageWithParts].self, from: data) {
            return MessageTranscriptDecode(messages: direct, diagnostics: [])
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw MessageTranscriptError.invalidJSON
        }

        if let rows = object as? [Any] {
            return try decodeMessageContainers(rows, prefix: "messages")
        }

        guard let dict = object as? [String: Any] else {
            throw MessageTranscriptError.unsupportedShape
        }
        if let rows = dict["messages"] as? [Any] ?? dict["data"] as? [Any] ?? dict["result"] as? [Any] {
            return try decodeMessageContainers(rows, prefix: "messages")
        }
        if dict["info"] is [String: Any] || dict["message"] is [String: Any] || (dict["role"] is String && dict["id"] is String) {
            return try decodeMessageContainers([dict], prefix: "messages")
        }
        throw MessageTranscriptError.unsupportedShape
    }

    private nonisolated static func decodeMessageContainers(_ rows: [Any], prefix: String) throws -> MessageTranscriptDecode {
        if rows.isEmpty {
            return MessageTranscriptDecode(messages: [], diagnostics: [])
        }
        var messages: [MessageWithParts] = []
        var diagnostics: [WireDecodeDiagnostic] = []
        for (index, row) in rows.enumerated() {
            let path = "\(prefix)[\(index)]"
            guard let container = row as? [String: Any] else {
                diagnostics.append(WireDecodeDiagnostic(codingPath: path, reason: "typeMismatch"))
                continue
            }
            let decoded = decodeMessageRecord(container, path: path)
            if let record = decoded.record {
                messages.append(record)
                diagnostics.append(contentsOf: decoded.diagnostics)
            } else {
                diagnostics.append(contentsOf: decoded.diagnostics)
            }
        }
        if messages.isEmpty {
            logMessageDecodeDiagnostics(diagnostics)
            throw MessageTranscriptError.noneDecoded(diagnostics: diagnostics)
        }
        return MessageTranscriptDecode(messages: messages, diagnostics: diagnostics)
    }

    private nonisolated static func decodeMessageRecord(
        _ container: [String: Any],
        path: String
    ) -> (record: MessageWithParts?, diagnostics: [WireDecodeDiagnostic]) {
        if let direct = try? decodeModel(container, as: MessageWithParts.self) {
            return (direct, [])
        }

        let infoObject = (container["info"] as? [String: Any]) ?? (container["message"] as? [String: Any]) ?? container
        let infoPath: String
        if container["info"] is [String: Any] {
            infoPath = path + ".info"
        } else if container["message"] is [String: Any] {
            infoPath = path + ".message"
        } else {
            infoPath = path
        }
        let info: Message
        do {
            info = try decodeModel(infoObject, as: Message.self)
        } catch {
            return (nil, [diagnostic(error, prefix: infoPath)])
        }

        let partsValue = container["parts"]
        if partsValue == nil {
            return (MessageWithParts(info: info, parts: []), [])
        }
        guard let partRows = partsValue as? [Any] else {
            return (
                MessageWithParts(info: info, parts: []),
                [WireDecodeDiagnostic(codingPath: path + ".parts", reason: "typeMismatch")]
            )
        }

        var parts: [Part] = []
        var diagnostics: [WireDecodeDiagnostic] = []
        for (index, partRow) in partRows.enumerated() {
            let partPath = path + ".parts[\(index)]"
            guard let partObject = partRow as? [String: Any] else {
                diagnostics.append(WireDecodeDiagnostic(codingPath: partPath, reason: "typeMismatch"))
                continue
            }
            do {
                parts.append(try decodeModel(partObject, as: Part.self))
            } catch {
                diagnostics.append(diagnostic(error, prefix: partPath))
            }
        }
        return (MessageWithParts(info: info, parts: parts), diagnostics)
    }

    private nonisolated static func decodeModel<T: Decodable>(_ value: Any, as type: T.Type) throws -> T {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "invalid JSON object"))
        }
        return try JSONDecoder().decode(type, from: data)
    }

    private nonisolated static func diagnostic(_ error: Error, prefix: String) -> WireDecodeDiagnostic {
        if let decoding = error as? DecodingError {
            return WireDecodeDiagnostic(decoding, prefix: prefix)
        }
        return WireDecodeDiagnostic(codingPath: prefix, reason: "dataCorrupted")
    }

    private nonisolated static func logMessageDecodeDiagnostics(_ diagnostics: [WireDecodeDiagnostic]) {
        for item in diagnostics {
            logger.warning("messages decode path=\(item.codingPath, privacy: .public) reason=\(item.reason, privacy: .public)")
        }
    }

    func promptAsync(
        sessionID: String,
        messageID: String,
        text: String,
        attachments: [ComposerImageAttachment] = [],
        agent: String = "build",
        model: Message.ModelInfo?,
        directory: String?
    ) async throws {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            // V2 takes the agent and model on their own routes: an empty
            // agent means "leave the session's as-is".
            try await promptAsyncV2(
                sessionID: sessionID,
                messageID: messageID,
                text: text,
                attachments: attachments,
                agent: agent,
                model: model
            )
            return
        }
        // V1 bodies carry the agent inline, and older servers have no default
        // agent to fall back to: send the legacy name when the caller omits it.
        let agentName = agent.isEmpty ? AgentInfo.fallbackAgentName : agent
        struct PromptBody: Encodable {
            let messageID: String
            let parts: [PartInput]
            let agent: String
            let model: ModelInput?
            struct PartInput: Encodable {
                let type: String
                let text: String?
                let mime: String?
                let filename: String?
                let url: String?

                static func text(_ text: String) -> PartInput {
                    PartInput(type: "text", text: text, mime: nil, filename: nil, url: nil)
                }

                static func file(_ attachment: ComposerImageAttachment) -> PartInput {
                    PartInput(type: "file", text: nil, mime: attachment.mime, filename: attachment.filename, url: attachment.dataURL)
                }
            }
            struct ModelInput: Encodable {
                let providerID: String
                let modelID: String
            }
        }
        var parts: [PromptBody.PartInput] = []
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            parts.append(.text(text))
        }
        parts.append(contentsOf: attachments.map { .file($0) })
        let body = PromptBody(
            messageID: messageID,
            parts: parts,
            agent: agent,
            model: model.map { .init(providerID: $0.providerID, modelID: $0.modelID) }
        )
        let bodyData = try JSONEncoder().encode(body)
        let queryItems = directory.map { [URLQueryItem(name: "directory", value: $0)] }
        let (data, http) = try await makeRequest(
            path: "/session/\(sessionID)/prompt_async",
            method: "POST",
            queryItems: queryItems,
            body: bodyData
        )
        if http.statusCode != 204 {
            throw APIError.httpError(statusCode: http.statusCode, data: data)
        }
    }

    /// V2 prompts carry text, not parts, and the agent and the model are
    /// switched with their own routes before the prompt is sent.
    private func promptAsyncV2(
        sessionID: String,
        messageID: String,
        text: String,
        attachments: [ComposerImageAttachment],
        agent: String,
        model: Message.ModelInfo?,
        transportToken: UInt64? = nil
    ) async throws {
        let trimmedAgent = agent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAgent.isEmpty {
            struct AgentBody: Encodable {
                let agent: String
            }
            let data = try JSONEncoder().encode(AgentBody(agent: trimmedAgent))
            let (_, http) = try await makeRequest(
                path: "/api/session/\(sessionID)/agent",
                method: "POST",
                body: data,
                liveToken: transportToken
            )
            guard http.statusCode == 204 else {
                throw APIError.httpError(statusCode: http.statusCode, data: Data())
            }
        }

        if let model {
            struct ModelInput: Encodable {
                let id: String
                let providerID: String
            }
            struct ModelBody: Encodable {
                let model: ModelInput
            }
            let data = try JSONEncoder().encode(
                ModelBody(model: ModelInput(id: model.modelID, providerID: model.providerID))
            )
            let (_, http) = try await makeRequest(
                path: "/api/session/\(sessionID)/model",
                method: "POST",
                body: data,
                liveToken: transportToken
            )
            guard http.statusCode == 204 else {
                throw APIError.httpError(statusCode: http.statusCode, data: Data())
            }
        }

        var body = try V2Mapper.promptBody(text: text, files: attachments)
        if !messageID.isEmpty {
            // V2 echoes a client-supplied message id back.
            body = try V2Mapper.promptBody(text: text, files: attachments, messageID: messageID)
        }
        let (data, http) = try await makeRequest(
            path: "/api/session/\(sessionID)/prompt",
            method: "POST",
            body: body,
            liveToken: transportToken
        )
        guard http.statusCode == 200 else {
            throw APIError.httpError(statusCode: http.statusCode, data: data)
        }
    }

    func abort(sessionID: String) async throws {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            let (data, http) = try await makeRequest(path: "/api/session/\(sessionID)/interrupt", method: "POST", body: Data("{}".utf8))
            if http.statusCode != 200 {
                throw APIError.httpError(statusCode: http.statusCode, data: data)
            }
            return
        }
        let (data, http) = try await makeRequest(path: "/session/\(sessionID)/abort", method: "POST")
        if http.statusCode != 200 {
            throw APIError.httpError(statusCode: http.statusCode, data: data)
        }
    }

    func sessionStatus() async throws -> [String: SessionStatus] {
        try await sessionStatus(directory: nil)
    }

    func sessionStatus(directory: String?) async throws -> [String: SessionStatus] {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            // V2 has no status poll: the active map lists the busy sessions.
            let (data, _) = try await makeRequest(path: "/api/session/active")
            return try V2Mapper.activeSessionStatuses(from: data)
        }
        let query = directory.map { [URLQueryItem(name: "directory", value: $0)] } ?? []
        let (data, _) = try await makeRequest(path: "/session/status", queryItems: query)
        return try JSONDecoder().decode([String: SessionStatus].self, from: data)
    }

    enum PermissionResponse: String, Encodable {
        case once
        case always
        case reject
    }

    struct PermissionRequest: Codable, Identifiable {
        struct ToolRef: Codable {
            let messageID: String?
            let callID: String?
        }

        struct Metadata: Codable {
            let filepath: String?
            let parentDir: String?
        }

        let id: String
        let sessionID: String
        let permission: String?
        let patterns: [String]?
        let metadata: Metadata?
        let always: [String]?
        let tool: ToolRef?
    }

    func pendingPermissions() async throws -> [PermissionRequest] {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            // V2 lists permissions per session.
            var requests: [PermissionRequest] = []
            for sessionID in knownSessionIDs {
                let (data, _) = try await makeRequest(path: "/api/session/\(sessionID)/permission")
                requests.append(contentsOf: try V2Mapper.permissions(from: data))
            }
            return requests
        }
        let (data, _) = try await makeRequest(path: "/permission")
        return try JSONDecoder().decode([PermissionRequest].self, from: data)
    }

    func respondPermission(sessionID: String, permissionID: String, response: PermissionResponse) async throws {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            struct DecisionBody: Encodable {
                let decision: String
            }
            let data = try JSONEncoder().encode(DecisionBody(decision: response.rawValue))
            let (responseData, http) = try await makeRequest(
                path: "/api/session/\(sessionID)/permission/\(permissionID)/reply",
                method: "POST",
                body: data
            )
            guard http.statusCode == 204 else {
                throw APIError.httpError(statusCode: http.statusCode, data: responseData)
            }
            return
        }
        struct Body: Encodable {
            let response: PermissionResponse
        }
        let data = try JSONEncoder().encode(Body(response: response))
        let (responseData, http) = try await makeRequest(
            path: "/session/\(sessionID)/permissions/\(permissionID)",
            method: "POST",
            body: data
        )
        if http.statusCode != 200 {
            throw APIError.httpError(statusCode: http.statusCode, data: responseData)
        }
    }

    func pendingQuestions() async throws -> [QuestionRequest] {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            // V2 lists forms per session.
            var questions: [QuestionRequest] = []
            for sessionID in knownSessionIDs {
                let (data, _) = try await makeRequest(path: "/api/session/\(sessionID)/form")
                questions.append(contentsOf: try V2Mapper.questions(from: data))
                for (id, entry) in try V2Mapper.formReplyTable(from: data) {
                    formReplyTable[id] = entry
                }
            }
            return questions
        }
        let (data, _) = try await makeRequest(path: "/question")
        return try JSONDecoder().decode([QuestionRequest].self, from: data)
    }

    /// Register the reply table of a form that arrived over the event stream.
    ///
    /// The app shows the options of a form by their label and the server wants
    /// their value, so the mapping has to exist before the answer is sent. A
    /// form that arrives as an event is not in the polled list yet — the poll
    /// only runs when the stream connects or a session is opened — so the
    /// event itself has to bring the mapping.
    func rememberFormReplyTable(from form: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: form),
              let entry = try? V2Mapper.formReplyEntry(from: data) else {
            return
        }
        formReplyTable[entry.id] = entry.entry
    }

    func replyQuestion(requestID: String, answers: [[String]]) async throws {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            guard let entry = formReplyTable[requestID] else {
                throw APIError.httpError(statusCode: 404, data: Data())
            }
            // V2 answers a form with `{key: value}`; the app collects labels.
            var answer: [String: String] = [:]
            for (index, labels) in answers.enumerated() {
                guard index < entry.fields.count else { continue }
                let field = entry.fields[index]
                answer[field.key] = entry.values(for: field.key, labels: labels).first ?? ""
            }
            struct AnswerBody: Encodable {
                let answer: [String: String]
            }
            let data = try JSONEncoder().encode(AnswerBody(answer: answer))
            let (responseData, http) = try await makeRequest(
                path: "/api/session/\(entry.sessionID)/form/\(requestID)/reply",
                method: "POST",
                body: data
            )
            guard http.statusCode == 204 else {
                throw APIError.httpError(statusCode: http.statusCode, data: responseData)
            }
            return
        }
        struct Body: Encodable {
            let answers: [[String]]
        }
        let data = try JSONEncoder().encode(Body(answers: answers))
        let (responseData, _) = try await makeRequest(path: "/question/\(requestID)/reply", method: "POST", body: data)
        try acceptEmptyOrJSONBoolean(responseData)
    }

    func rejectQuestion(requestID: String) async throws {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            guard let entry = formReplyTable[requestID] else {
                throw APIError.httpError(statusCode: 404, data: Data())
            }
            let (responseData, http) = try await makeRequest(
                path: "/api/session/\(entry.sessionID)/form/\(requestID)",
                method: "DELETE"
            )
            guard http.statusCode == 204 else {
                throw APIError.httpError(statusCode: http.statusCode, data: responseData)
            }
            return
        }
        let (responseData, _) = try await makeRequest(path: "/question/\(requestID)/reject", method: "POST")
        try acceptEmptyOrJSONBoolean(responseData)
    }

    func providers() async throws -> ProvidersResponse {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            let registry = try await providerRegistry()
            let (defaultData, _) = try await makeRequest(path: "/api/model/default")
            let defaultModel = try V2Mapper.defaultModel(from: defaultData)
            return ProvidersResponse(
                providers: registry.providers,
                default: defaultModel.map { DefaultProvider(providerID: $0.providerID, modelID: $0.modelID) }
            )
        }
        let (data, _) = try await makeRequest(path: "/config/providers")
        return try JSONDecoder().decode(ProvidersResponse.self, from: data)
    }

    /// `/provider`: full provider registry including which providers are
    /// connected (authenticated or keyless-local), used to scope the model
    /// picker to models the user can actually run.
    func providerRegistry() async throws -> ProviderRegistryResponse {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            let (providerData, _) = try await makeRequest(path: "/api/provider")
            let registry = try V2Mapper.providerRegistry(from: providerData)
            // The provider list carries no models; the model list does.
            let (modelData, _) = try await makeRequest(path: "/api/model")
            let models = try V2Mapper.models(from: modelData)
            var providers = registry.providers
            for index in providers.indices {
                let providerID = providers[index].id
                let owned = models.filter { $0.providerID == providerID }
                guard !owned.isEmpty else { continue }
                providers[index] = ConfigProvider(
                    id: providerID,
                    name: providers[index].name,
                    models: Dictionary(uniqueKeysWithValues: owned.map { ($0.id, $0) })
                )
            }
            return ProviderRegistryResponse(providers: providers, connectedProviderIDs: registry.connectedProviderIDs)
        }
        let (data, _) = try await makeRequest(path: "/provider")
        return try JSONDecoder().decode(ProviderRegistryResponse.self, from: data)
    }

    func agents() async throws -> [AgentInfo] {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            let (data, _) = try await makeRequest(path: "/api/agent")
            return try V2Mapper.agents(from: data)
        }
        let (data, _) = try await makeRequest(path: "/agent")
        return try JSONDecoder().decode([AgentInfo].self, from: data)
    }

    func sessionDiff(sessionID: String) async throws -> [FileDiff] {
        try await sessionDiff(sessionID: sessionID, from: nil, to: nil, context: nil)
    }

    /// The diff of the files a turn changed.
    ///
    /// V2 scopes the diff to a turn: `from` is the user message that started
    /// it, `to` extends the range through a later turn, and `context` sets how
    /// many unchanged lines surround each hunk. V1 has no such parameters and
    /// always answers with the whole session's diff.
    func sessionDiff(sessionID: String, from: String?, to: String?, context: Int?) async throws -> [FileDiff] {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            var queryItems: [URLQueryItem] = []
            if let from { queryItems.append(URLQueryItem(name: "from", value: from)) }
            if let to { queryItems.append(URLQueryItem(name: "to", value: to)) }
            if let context { queryItems.append(URLQueryItem(name: "context", value: String(context))) }
            let (data, _) = try await makeRequest(
                path: "/api/session/\(sessionID)/diff",
                queryItems: queryItems.isEmpty ? nil : queryItems
            )
            return try V2Mapper.diff(from: data)
        }
        let (data, _) = try await makeRequest(path: "/session/\(sessionID)/diff")
        return try JSONDecoder().decode([FileDiff].self, from: data)
    }

    func sessionTodos(sessionID: String) async throws -> [TodoItem] {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            // V2 exposes no todo route. The panel stays empty rather than
            // guessing a stand-in.
            return []
        }
        let (data, _) = try await makeRequest(path: "/session/\(sessionID)/todo")
        return try JSONDecoder().decode([TodoItem].self, from: data)
    }

    func fileList(path: String = "", directory: String? = nil) async throws -> [FileNode] {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            var queryItems = [URLQueryItem(name: "path", value: path)]
            if let directory, !directory.isEmpty {
                queryItems.append(URLQueryItem(name: "location[directory]", value: directory))
            }
            let (data, _) = try await makeRequest(path: "/api/fs/list", queryItems: queryItems)
            return try V2Mapper.fileList(from: data)
        }
        var queryItems = [URLQueryItem(name: "path", value: path)]
        if let directory, !directory.isEmpty {
            queryItems.append(URLQueryItem(name: "directory", value: directory))
        }
        let (data, _) = try await makeRequest(path: "/file", queryItems: queryItems)
        return try JSONDecoder().decode([FileNode].self, from: data)
    }

    func fileContent(path: String, directory: String? = nil) async throws -> FileContent {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            let relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
            var components = URLComponents(string: "\(baseURL)/api/fs/read/\(relative)")!
            if let directory, !directory.isEmpty {
                components.queryItems = [URLQueryItem(name: "location[directory]", value: directory)]
            }
            guard let url = components.url else { throw APIError.invalidURL }
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            applyCredentials(to: &request)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.httpError(statusCode: 0, data: data)
            }
            guard (200..<300).contains(http.statusCode) else {
                throw APIError.httpError(statusCode: http.statusCode, data: data)
            }
            if let text = String(data: data, encoding: .utf8) {
                return FileContent(type: "text", content: text)
            }
            return FileContent(type: "binary", content: nil)
        }
        var queryItems = [URLQueryItem(name: "path", value: path)]
        if let directory, !directory.isEmpty {
            queryItems.append(URLQueryItem(name: "directory", value: directory))
        }
        let (data, _) = try await makeRequest(path: "/file/content", queryItems: queryItems)
        return try JSONDecoder().decode(FileContent.self, from: data)
    }

    func findFile(query: String, limit: Int = 50) async throws -> [String] {
        try await findFile(query: query, limit: limit, directory: nil)
    }

    func findFile(query: String, limit: Int, directory: String?) async throws -> [String] {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            var queryItems = [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "limit", value: String(limit)),
            ]
            if let directory, !directory.isEmpty {
                queryItems.append(URLQueryItem(name: "location[directory]", value: directory))
            }
            let (data, _) = try await makeRequest(path: "/api/fs/find", queryItems: queryItems)
            return try V2Mapper.foundPaths(from: data)
        }
        var queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let directory, !directory.isEmpty {
            queryItems.append(URLQueryItem(name: "directory", value: directory))
        }
        let (data, _) = try await makeRequest(path: "/find/file", queryItems: queryItems)
        return try JSONDecoder().decode([String].self, from: data)
    }

    func fileStatus() async throws -> [FileStatusEntry] {
        try await fileStatus(directory: nil)
    }

    func fileStatus(directory: String?) async throws -> [FileStatusEntry] {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            // The location matters: without it the server resolves the
            // request against its own working directory, which can be a large
            // repository, and the call then hangs.
            var queryItems: [URLQueryItem] = []
            if let directory, !directory.isEmpty {
                queryItems.append(URLQueryItem(name: "location[directory]", value: directory))
            }
            let (data, _) = try await makeRequest(path: "/api/vcs/status", queryItems: queryItems.isEmpty ? nil : queryItems)
            return try V2Mapper.fileStatus(from: data)
        }
        let (data, _) = try await makeRequest(path: "/file/status")
        return try JSONDecoder().decode([FileStatusEntry].self, from: data)
    }

    func forkSession(sessionID: String, messageID: String? = nil) async throws -> Session {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            struct ForkBody: Encodable {
                let before: String?
            }
            let data = try JSONEncoder().encode(ForkBody(before: messageID))
            let (responseData, _) = try await makeRequest(
                path: "/api/session/\(sessionID)/fork",
                method: "POST",
                body: data
            )
            let forked = try V2Mapper.session(from: responseData)
            knownSessionIDs.insert(forked.id)
            return forked
        }
        struct ForkBody: Encodable {
            let messageID: String?
        }
        let body = ForkBody(messageID: messageID)
        let data = try JSONEncoder().encode(body)
        let (responseData, _) = try await makeRequest(
            path: "/session/\(sessionID)/fork",
            method: "POST",
            body: data
        )
        return try JSONDecoder().decode(Session.self, from: responseData)
    }

    func revertSession(sessionID: String, messageID: String, partID: String? = nil) async throws -> Session {
        let generation = try await resolvedGeneration()
        if generation == .v2 {
            // V2 stages the revert and answers with the staged message, not
            // the session: read the session back afterwards.
            struct RevertBody: Encodable {
                let messageID: String
            }
            let data = try JSONEncoder().encode(RevertBody(messageID: messageID))
            let (_, http) = try await makeRequest(
                path: "/api/session/\(sessionID)/revert/stage",
                method: "POST",
                body: data
            )
            guard http.statusCode == 200 else {
                throw APIError.httpError(statusCode: http.statusCode, data: Data())
            }
            return try await session(sessionID: sessionID)
        }
        struct RevertBody: Encodable {
            let messageID: String
            let partID: String?
        }

        let data = try JSONEncoder().encode(RevertBody(messageID: messageID, partID: partID))
        let (responseData, _) = try await makeRequest(
            path: "/session/\(sessionID)/revert",
            method: "POST",
            body: data
        )
        return try JSONDecoder().decode(Session.self, from: responseData)
    }



















    private func ensureLiveTransport(_ token: UInt64) throws {
    }

    private func postLivePrompt(sessionID: String, directory: String?, body: Data, transportToken: UInt64) async throws {
        let queryItems = directory.flatMap { value -> [URLQueryItem]? in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : [URLQueryItem(name: "directory", value: trimmed)]
        }
        let (data, http) = try await makeRequest(
            path: "/session/\(sessionID)/prompt_async",
            method: "POST",
            queryItems: queryItems,
            body: body,
            liveToken: transportToken
        )
        Self.logger.debug("live prompt status=\(http.statusCode, privacy: .public)")
        if http.statusCode != 204 {
            throw APIError.httpError(statusCode: http.statusCode, data: data)
        }
    }

    private nonisolated static func historyHasOlder(_ response: HTTPURLResponse) -> Bool {
        if response.value(forHTTPHeaderField: "X-Next-Cursor") != nil { return true }
        return linkDeclaresNext(response.value(forHTTPHeaderField: "Link"))
    }

    private nonisolated static func liveMessageQuery(limit: Int, before: String?, directory: String?) -> [URLQueryItem] {
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let before {
            items.append(URLQueryItem(name: "before", value: before))
        }
        if let directory {
            items.append(URLQueryItem(name: "directory", value: directory))
        }
        return items
    }

    private nonisolated static func liveDirectoryQuery(_ directory: String?) -> [URLQueryItem]? {
        guard let directory else { return nil }
        return [URLQueryItem(name: "directory", value: directory)]
    }


    nonisolated static func historyNextCursor(_ response: HTTPURLResponse) -> String? {
        if let cursor = response.value(forHTTPHeaderField: "X-Next-Cursor") {
            return cursor
        }
        return linkBeforeCursor(response.value(forHTTPHeaderField: "Link"))
    }

    /// V2 hands out opaque pagination cursors: base64url JSON carrying the
    /// message id, the ordering and the direction to walk. They cannot be
    /// combined with `order` and they are not interchangeable with the V1
    /// `before` cursor, so only reuse a value that really is a V2 cursor.
    nonisolated static func v2MessageCursor(_ raw: String) -> String? {
        guard !raw.isEmpty, let decoded = Self.decodeBase64URL(raw) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: decoded) as? [String: Any] else { return nil }
        guard object["order"] != nil, object["direction"] != nil else { return nil }
        return raw
    }

    /// The cursor that walks further back through a V2 transcript.
    nonisolated static func v2MessageNextCursor(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cursor = object["cursor"] as? [String: Any],
              let next = cursor["next"] as? String,
              !next.isEmpty else {
            return nil
        }
        return next
    }

    private nonisolated static func decodeBase64URL(_ raw: String) -> Data? {
        var normalized = raw.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder > 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: normalized)
    }

    nonisolated static func linkBeforeCursor(_ header: String?) -> String? {
        guard let header else { return nil }
        var search = header[...]
        while let open = search.firstIndex(of: "<") {
            let afterOpen = search.index(after: open)
            guard let close = search[afterOpen...].firstIndex(of: ">") else { return nil }
            let target = String(search[afterOpen..<close])
            let afterClose = search.index(after: close)
            let nextOpen = search[afterClose...].firstIndex(of: "<") ?? search.endIndex
            if relationIsNext(String(search[afterClose..<nextOpen])), let before = opaqueBefore(in: target) {
                return before
            }
            search = search[nextOpen...]
        }
        return nil
    }

    private nonisolated static func linkDeclaresNext(_ header: String?) -> Bool {
        guard let header else { return false }
        var search = header[...]
        while let open = search.firstIndex(of: "<") {
            guard let close = search[search.index(after: open)...].firstIndex(of: ">") else { return false }
            let afterClose = search.index(after: close)
            let nextOpen = search[afterClose...].firstIndex(of: "<") ?? search.endIndex
            if relationIsNext(String(search[afterClose..<nextOpen])) { return true }
            search = search[nextOpen...]
        }
        return false
    }

    private nonisolated static func relationIsNext(_ params: String) -> Bool {
        for part in params.split(separator: ";") {
            let piece = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let eq = piece.firstIndex(of: "=") else { continue }
            guard piece[..<eq].trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("rel") == .orderedSame else { continue }
            var value = piece[piece.index(after: eq)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            return value.split(whereSeparator: { $0 == " " || $0 == "\t" }).contains { $0.caseInsensitiveCompare("next") == .orderedSame }
        }
        return false
    }

    private nonisolated static func opaqueBefore(in target: String) -> String? {
        guard let queryStart = target.firstIndex(of: "?") else { return nil }
        var query = target[target.index(after: queryStart)...]
        if let hash = query.firstIndex(of: "#") { query = query[..<hash] }
        for pair in query.split(separator: "&", omittingEmptySubsequences: false) {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            guard parts.first == "before" else { continue }
            let raw = parts.count > 1 ? parts[1] : ""
            return raw.removingPercentEncoding ?? raw
        }
        return nil
    }
}

nonisolated struct FileNode: Codable, Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let absolute: String?
    let type: String  // "directory" | "file"
    let ignored: Bool?
}

nonisolated struct FileContent: Codable {
    let type: String  // "text" | "binary"
    let content: String?
    var text: String? { type == "text" ? content : nil }
}

nonisolated struct FileStatusEntry: Codable {
    let path: String?
    let status: String?  // "added" | "modified" | "deleted" | "untracked"
}

nonisolated struct FileDiff: Codable, Identifiable, Hashable {
    var id: String { file }
    let file: String
    let before: String
    let after: String
    let additions: Int
    let deletions: Int
    let status: String?
    /// The server's unified patch text.
    ///
    /// V2 sends it as `patch` (and leaves `before` empty, so the patch is the
    /// only diff body it can show). V1 has no equivalent field — there the
    /// renderer derives a diff from `before`/`after` instead. Keeping the two
    /// apart lets the renderer tell them apart instead of guessing whether
    /// `after` holds a patch or file content.
    let patchText: String?

    enum CodingKeys: String, CodingKey {
        case file, path, before, after, additions, deletions, status, patch
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        file = (try? c.decode(String.self, forKey: .file)) ?? (try? c.decode(String.self, forKey: .path)) ?? ""
        before = (try? c.decode(String.self, forKey: .before)) ?? ""
        after = (try? c.decode(String.self, forKey: .after)) ?? ""
        additions = (try? c.decode(Int.self, forKey: .additions)) ?? 0
        deletions = (try? c.decode(Int.self, forKey: .deletions)) ?? 0
        status = try? c.decode(String.self, forKey: .status)
        patchText = try? c.decode(String.self, forKey: .patch)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(file, forKey: .file)
        try c.encode(before, forKey: .before)
        try c.encode(after, forKey: .after)
        try c.encode(additions, forKey: .additions)
        try c.encode(deletions, forKey: .deletions)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(patchText, forKey: .patch)
    }

    init(
        file: String,
        before: String,
        after: String,
        additions: Int,
        deletions: Int,
        status: String?,
        patchText: String? = nil
    ) {
        self.file = file
        self.before = before
        self.after = after
        self.additions = additions
        self.deletions = deletions
        self.status = status
        self.patchText = patchText
    }

    func hash(into hasher: inout Hasher) { hasher.combine(file) }
    static func == (lhs: FileDiff, rhs: FileDiff) -> Bool { lhs.file == rhs.file }
}

/// OpenCode GET /config/providers
///
/// Server responses vary across versions:
/// - `providers` may be an array (`[{id, name, models}]`) or a dictionary (`{ providerID: ProviderInfo }`)
/// - `models` may be a dictionary (`{ modelID: ModelInfo }`) or an array (`[{id, ...}]`)
/// - `ProviderModel.id` / `ConfigProvider.id` may be missing when encoded as dictionary values
nonisolated struct ProvidersResponse: Decodable {
    let providers: [ConfigProvider]
    let `default`: DefaultProvider?

    init(providers: [ConfigProvider], default defaultModel: DefaultProvider?) {
        self.providers = providers
        self.default = defaultModel
    }

    private enum CodingKeys: String, CodingKey {
        case providers
        case `default`
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        `default` = try? c.decode(DefaultProvider.self, forKey: .default)

        if let arr = try? c.decode([ConfigProvider].self, forKey: .providers) {
            providers = arr
            return
        }

        if let dict = try? c.decode([String: ConfigProvider].self, forKey: .providers) {
            providers = dict
                .map { (key, value) in
                    if !value.id.isEmpty { return value }
                    return ConfigProvider(id: key, name: value.name, models: value.models)
                }
                .sorted { $0.id < $1.id }
            return
        }

        providers = []
    }
}

/// Response of `/provider`: every known provider plus the subset that is
/// connected (authenticated, or local/keyless providers like a custom
/// Ollama endpoint, which count as connected without credentials).
nonisolated struct ProviderRegistryResponse: Decodable {
    let providers: [ConfigProvider]
    let connectedProviderIDs: [String]

    private enum CodingKeys: String, CodingKey {
        case all
        case connected
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        providers = (try? c.decode([ConfigProvider].self, forKey: .all)) ?? []
        connectedProviderIDs = (try? c.decode([String].self, forKey: .connected)) ?? []
    }

    init(providers: [ConfigProvider], connectedProviderIDs: [String]) {
        self.providers = providers
        self.connectedProviderIDs = connectedProviderIDs
    }
}

nonisolated struct ConfigProvider: Decodable {
    let id: String
    let name: String?
    let models: [String: ProviderModel]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case models
    }

    init(id: String, name: String?, models: [String: ProviderModel]) {
        self.id = id
        self.name = name
        self.models = models
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        name = try? c.decode(String.self, forKey: .name)
        if let dict = try? c.decode([String: ProviderModel].self, forKey: .models) {
            var fixed: [String: ProviderModel] = [:]
            fixed.reserveCapacity(dict.count)
            for (key, value) in dict {
                if value.id.isEmpty {
                    fixed[key] = ProviderModel(
                        id: key,
                        name: value.name,
                        providerID: value.providerID,
                        limit: value.limit,
                        capabilities: value.capabilities,
                        family: value.family,
                        releaseDate: value.releaseDate
                    )
                } else {
                    fixed[key] = value
                }
            }
            models = fixed
            return
        }

        if let arr = try? c.decode([ProviderModel].self, forKey: .models) {
            var fixed: [String: ProviderModel] = [:]
            fixed.reserveCapacity(arr.count)
            for m in arr {
                let key = m.id
                if key.isEmpty { continue }
                fixed[key] = m
            }
            models = fixed
            return
        }

        models = [:]
    }
}

nonisolated struct ProviderModel: Decodable {
    let id: String
    let name: String?
    let providerID: String?
    let limit: ProviderModelLimit?
    let capabilities: ProviderModelCapabilities?
    let family: String?
    let releaseDate: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case providerID
        case providerId
        case limit
        case capabilities
        case family
        case releaseDate = "release_date"
    }

    init(
        id: String,
        name: String?,
        providerID: String?,
        limit: ProviderModelLimit?,
        capabilities: ProviderModelCapabilities? = nil,
        family: String? = nil,
        releaseDate: String? = nil
    ) {
        self.id = id
        self.name = name
        self.providerID = providerID
        self.limit = limit
        self.capabilities = capabilities
        self.family = family
        self.releaseDate = releaseDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        name = try? c.decode(String.self, forKey: .name)
        providerID = (try? c.decode(String.self, forKey: .providerID)) ?? (try? c.decode(String.self, forKey: .providerId))
        limit = try? c.decode(ProviderModelLimit.self, forKey: .limit)
        capabilities = try? c.decode(ProviderModelCapabilities.self, forKey: .capabilities)
        family = try? c.decode(String.self, forKey: .family)
        releaseDate = try? c.decode(String.self, forKey: .releaseDate)
    }
}

nonisolated struct ProviderModelCapabilities: Codable {
    let reasoning: Bool?
    let toolCall: Bool?
    let attachment: Bool?
    let input: ProviderModelIO?
    let output: ProviderModelIO?

    private enum CodingKeys: String, CodingKey {
        case reasoning
        case toolCall = "toolcall"
        case attachment
        case input
        case output
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reasoning = try? c.decode(Bool.self, forKey: .reasoning)
        toolCall = try? c.decode(Bool.self, forKey: .toolCall)
        attachment = try? c.decode(Bool.self, forKey: .attachment)
        input = try? c.decode(ProviderModelIO.self, forKey: .input)
        output = try? c.decode(ProviderModelIO.self, forKey: .output)
    }

    init(reasoning: Bool?, toolCall: Bool?, attachment: Bool?, input: ProviderModelIO?, output: ProviderModelIO?) {
        self.reasoning = reasoning
        self.toolCall = toolCall
        self.attachment = attachment
        self.input = input
        self.output = output
    }

    /// Chat-capable means the model can produce text output. Filters out
    /// embedding/TTS/image-generation-only models from the picker.
    var isChatCapable: Bool {
        // Missing capability info is treated as capable: older servers may
        // not report it, and a false negative would hide working models.
        guard let output else { return true }
        return output.text ?? true
    }
}

nonisolated struct ProviderModelIO: Codable {
    let text: Bool?
    let audio: Bool?
    let image: Bool?
    let video: Bool?
    let pdf: Bool?
}

nonisolated struct ProviderModelLimit: Codable {
    let context: Int?
    let input: Int?
    let output: Int?
}

nonisolated struct DefaultProvider: Codable {
    let providerID: String
    let modelID: String
}

nonisolated struct HealthResponse: Codable {
    let healthy: Bool
    let version: String?
}

enum APIError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, data: Data)
    /// The host answered, but not as an OpenCode V1 or V2 API.
    case unsupportedServer

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .unsupportedServer:
            return "This server does not speak the OpenCode API."
        case .httpError(let statusCode, let data):
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if body.isEmpty {
                return "HTTP \(statusCode)"
            }
            return "HTTP \(statusCode): \(body)"
        }
    }
}

protocol APIClientProtocol: Actor {
    func configure(baseURL: String, username: String?, password: String?)
    /// Which OpenCode API the client speaks. `.auto` means it has not probed yet.
    func currentGeneration() -> ServerGeneration
    /// Probe which OpenCode API the host speaks.
    func detectGeneration() async throws -> ServerGeneration
    func health() async throws -> HealthResponse
    func projects() async throws -> [Project]
    func projectCurrent() async throws -> Project?
    func sessions(directory: String?, limit: Int) async throws -> [Session]
    func session(sessionID: String) async throws -> Session
    func createSession(title: String?, directory: String?) async throws -> Session
    func updateSession(sessionID: String, title: String) async throws -> Session
    func updateSessionArchived(sessionID: String, archived: Int) async throws -> Session
    func deleteSession(sessionID: String) async throws
    func messages(sessionID: String, limit: Int?) async throws -> [MessageWithParts]
    func promptAsync(sessionID: String, messageID: String, text: String, attachments: [ComposerImageAttachment], agent: String, model: Message.ModelInfo?, directory: String?) async throws
    func promptStructured(sessionID: String, messageID: String?, text: String, system: String, format: StructuredOutputFormat, agent: String, model: Message.ModelInfo) async throws -> MessageWithParts
    func abort(sessionID: String) async throws
    func sessionStatus() async throws -> [String: SessionStatus]
    func sessionStatus(directory: String?) async throws -> [String: SessionStatus]
    func pendingPermissions() async throws -> [APIClient.PermissionRequest]
    func respondPermission(sessionID: String, permissionID: String, response: APIClient.PermissionResponse) async throws
    func pendingQuestions() async throws -> [QuestionRequest]
    func replyQuestion(requestID: String, answers: [[String]]) async throws
    func rejectQuestion(requestID: String) async throws
    /// Register the reply table of a form that arrived over the event stream.
    func rememberFormReplyTable(from form: [String: Any])
    func providers() async throws -> ProvidersResponse
    func providerRegistry() async throws -> ProviderRegistryResponse
    func agents() async throws -> [AgentInfo]
    func sessionDiff(sessionID: String) async throws -> [FileDiff]
    /// The diff of the files a turn changed. V2 scopes it to a turn; V1
    /// answers with the whole session and ignores the range.
    func sessionDiff(sessionID: String, from: String?, to: String?, context: Int?) async throws -> [FileDiff]
    func sessionTodos(sessionID: String) async throws -> [TodoItem]
    func fileList(path: String, directory: String?) async throws -> [FileNode]
    func fileContent(path: String, directory: String?) async throws -> FileContent
    func findFile(query: String, limit: Int) async throws -> [String]
    func fileStatus() async throws -> [FileStatusEntry]
    func forkSession(sessionID: String, messageID: String?) async throws -> Session
    func revertSession(sessionID: String, messageID: String, partID: String?) async throws -> Session
}

extension APIClient: APIClientProtocol {}

protocol FileDirectorySearching: APIClientProtocol {
    func findFile(query: String, limit: Int, directory: String?) async throws -> [String]
}

extension APIClient: FileDirectorySearching {}

extension APIClientProtocol {
    /// The turn-scoped diff of a client that does not scope diffs: the whole
    /// session's diff is the closest answer it can give.
    func sessionDiff(sessionID: String, from: String?, to: String?, context: Int?) async throws -> [FileDiff] {
        try await sessionDiff(sessionID: sessionID)
    }
    /// Register the reply table of a form that arrived over the event stream.
    ///
    /// Only V2 needs one: it answers a form with the options' values, while
    /// the app collects their labels. A client that speaks V1 has nothing to
    /// map.
    func rememberFormReplyTable(from form: [String: Any]) {}
    /// The status of a specific directory. V2 needs it: without a location
    /// the server resolves the request against its own working directory,
    /// which can be a large repository, and the call then hangs.
    func fileStatus(directory: String?) async throws -> [FileStatusEntry] {
        try await fileStatus()
    }
    /// Configure with a known generation. Clients that do not track one fall
    /// back to the plain configuration.
    func configure(baseURL: String, username: String?, password: String?, generation: ServerGeneration) {
        configure(baseURL: baseURL, username: username, password: password)
    }
    /// The generation of a client that does not track one.
    func currentGeneration() -> ServerGeneration { .auto }
    /// A client that does not probe keeps the historical V1 behaviour.
    func detectGeneration() async throws -> ServerGeneration { .auto }
    func sessionStatus(directory: String?) async throws -> [String: SessionStatus] {
        try await sessionStatus()
    }
    func promptStructured(
        sessionID: String,
        text: String,
        system: String,
        format: StructuredOutputFormat,
        agent: String,
        model: Message.ModelInfo
    ) async throws -> MessageWithParts {
        try await promptStructured(
            sessionID: sessionID,
            messageID: nil,
            text: text,
            system: system,
            format: format,
            agent: agent,
            model: model
        )
    }
}
