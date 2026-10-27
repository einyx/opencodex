//
//  SSEClient.swift
//  OpenCodeClient
//

import Foundation

nonisolated struct SSEEvent: Codable {
    let directory: String?
    let payload: SSEPayload
}

struct SSEPayload: Codable {
    let type: String
    let properties: [String: AnyCodable]?
}

nonisolated struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let string = try? container.decode(String.self) { value = string }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else if let array = try? container.decode([AnyCodable].self) { value = array.map { $0.value } }
        else if let dict = try? container.decode([String: AnyCodable].self) { value = dict.mapValues { $0.value } }
        else if container.decodeNil() { value = NSNull() }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let string as String: try container.encode(string)
        case let bool as Bool: try container.encode(bool)
        case let array as [Any]: try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { AnyCodable($0) })
        default: try container.encodeNil()
        }
    }
}

enum SSEStreamFailure: Error, Equatable, Sendable {
    case httpStatus(Int)
    case notEventStream

    var pausesAutomaticRetry: Bool {
        guard case .httpStatus(let code) = self else { return false }
        return code == 401 || code == 403
    }
}

nonisolated struct SSEStreamLease: @unchecked Sendable {
    var events: AsyncThrowingStream<SSEEvent, Error>
    var cancel: @Sendable () -> Void
}

nonisolated final class SSEConnectionCancel: @unchecked Sendable {
    private let lock = NSLock()
    private var producer: Task<Void, Never>?
    private var responseCancel: (@Sendable () -> Void)?
    private var cancelled = false
    private var closedResponse = false

    func bindProducer(_ task: Task<Void, Never>) {
        lock.lock()
        producer = task
        let shouldCancel = cancelled
        lock.unlock()
        if shouldCancel {
            task.cancel()
        }
    }

    func bindResponse(_ cancel: @escaping @Sendable () -> Void) {
        lock.lock()
        responseCancel = cancel
        let shouldClose = cancelled && !closedResponse
        if shouldClose {
            closedResponse = true
        }
        lock.unlock()
        if shouldClose {
            cancel()
        }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let producer = self.producer
        let close = closedResponse ? nil : responseCancel
        if close != nil {
            closedResponse = true
        }
        lock.unlock()
        producer?.cancel()
        close?()
    }
}

protocol SSEHTTPOpener: Sendable {
    func open(_ request: URLRequest) async throws -> SSEHTTPResponse
}

struct SSEHTTPResponse: Sendable {
    var statusCode: Int
    var contentType: String?
    var bytes: AsyncThrowingStream<UInt8, Error>
    var cancel: @Sendable () -> Void
}

nonisolated final class URLSessionSSEHTTPOpener: SSEHTTPOpener, @unchecked Sendable {
    func open(_ request: URLRequest) async throws -> SSEHTTPResponse {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let http = response as? HTTPURLResponse
        let handle = SSEConnectionCancel()
        let responseTask = bytes.task
        handle.bindResponse { responseTask.cancel() }
        let stream = AsyncThrowingStream<UInt8, Error> { continuation in
            // This opener inherits MainActor from the project's default
            // isolation. Keep per-byte forwarding off that executor: fast
            // global event streams otherwise fall seconds behind the server.
            let reader = Task.detached {
                do {
                    for try await byte in bytes {
                        try Task.checkCancellation()
                        continuation.yield(byte)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // Reuse the locked cancellation owner so cancellation before
            // reader registration also stops this detached task and request.
            handle.bindProducer(reader)
            continuation.onTermination = { _ in
                handle.cancel()
            }
        }
        return SSEHTTPResponse(
            statusCode: http?.statusCode ?? 0,
            contentType: http?.value(forHTTPHeaderField: "Content-Type"),
            bytes: stream,
            cancel: { handle.cancel() }
        )
    }
}

actor SSEClient {
    private let opener: any SSEHTTPOpener

    init(opener: any SSEHTTPOpener = URLSessionSSEHTTPOpener()) {
        self.opener = opener
    }

    nonisolated static func acceptHTTP(statusCode: Int, contentType: String?) throws {
        guard (200..<300).contains(statusCode) else {
            throw SSEStreamFailure.httpStatus(statusCode)
        }
        let mediaType = contentType?
            .split(separator: ";", maxSplits: 1)
            .first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() } ?? ""
        guard mediaType == "text/event-stream" else {
            throw SSEStreamFailure.notEventStream
        }
    }

    func connect(
        baseURL: String,
        username: String? = nil,
        password: String? = nil
    ) -> AsyncThrowingStream<SSEEvent, Error> {
        connectLease(baseURL: baseURL, username: username, password: password).events
    }

    func connectLease(
        baseURL: String,
        username: String? = nil,
        password: String? = nil,
        generation: ServerGeneration = .auto
    ) -> SSEStreamLease {
        let urlString = baseURL.hasPrefix("http") ? baseURL : "http://\(baseURL)"
        // V2 publishes on `/api/event`; V1 on `/global/event`.
        let path = generation == .v2 ? "/api/event" : "/global/event"
        guard let url = URL(string: "\(urlString)\(path)") else {
            return SSEStreamLease(
                events: AsyncThrowingStream { $0.finish(throwing: APIError.invalidURL) },
                cancel: {}
            )
        }
        if Task.isCancelled {
            return SSEStreamLease(events: AsyncThrowingStream { $0.finish() }, cancel: {})
        }
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        if let username, let password {
            let credential = "\(username):\(password)"
            if let data = credential.data(using: .utf8) {
                request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }

        let handle = SSEConnectionCancel()
        let opener = self.opener
        let events = AsyncThrowingStream<SSEEvent, Error> { continuation in
            let task = Task {
                if Task.isCancelled {
                    continuation.finish()
                    return
                }
                let opened: SSEHTTPResponse
                do {
                    opened = try await opener.open(request)
                } catch is CancellationError {
                    continuation.finish()
                    return
                } catch {
                    continuation.finish(throwing: error)
                    return
                }
                handle.bindResponse(opened.cancel)
                if Task.isCancelled {
                    handle.cancel()
                    continuation.finish()
                    return
                }
                do {
                    try Self.acceptHTTP(statusCode: opened.statusCode, contentType: opened.contentType)
                    try await Self.consume(opened.bytes, into: continuation, generation: generation)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                handle.cancel()
            }
            handle.bindProducer(task)
            continuation.onTermination = { _ in
                handle.cancel()
            }
        }
        if Task.isCancelled {
            handle.cancel()
        }
        return SSEStreamLease(events: events, cancel: { handle.cancel() })
    }

    private nonisolated static func consume(
        _ bytes: AsyncThrowingStream<UInt8, Error>,
        into continuation: AsyncThrowingStream<SSEEvent, Error>.Continuation,
        generation: ServerGeneration = .auto
    ) async throws {
        var lineBuffer = Data()
        var eventDataLines: [String] = []
        // One translator per connection: it carries the state of the tool
        // calls V2 splits over several frames.
        var translator = V2EventTranslator()

        func flushEventIfNeeded() {
            guard !eventDataLines.isEmpty else { return }
            let json = eventDataLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            eventDataLines.removeAll(keepingCapacity: true)

            guard !json.isEmpty, json != "[DONE]" else { return }
            let data = Data(json.utf8)
            if generation == .v2 {
                guard let frame = try? JSONDecoder().decode(V2EventTranslator.Frame.self, from: data),
                      let event = translator.translate(frame) else {
                    return
                }
                continuation.yield(event)
                return
            }
            if let event = try? JSONDecoder().decode(SSEEvent.self, from: data) {
                continuation.yield(event)
            }
        }

        for try await byte in bytes {
            try Task.checkCancellation()

            if byte == 0x0A {
                if lineBuffer.last == 0x0D { lineBuffer.removeLast() }
                let line = String(decoding: lineBuffer, as: UTF8.self)
                lineBuffer.removeAll(keepingCapacity: true)

                if line.isEmpty {
                    flushEventIfNeeded()
                    continue
                }

                if line.hasPrefix(":") {
                    continue
                }

                if line.hasPrefix("data:") {
                    var payload = String(line.dropFirst(5))
                    if payload.hasPrefix(" ") { payload.removeFirst() }
                    eventDataLines.append(payload)
                }

                continue
            }

            lineBuffer.append(byte)
        }

        flushEventIfNeeded()
    }
}

protocol SSEClientProtocol: Actor {
    func connect(baseURL: String, username: String?, password: String?) -> AsyncThrowingStream<SSEEvent, Error>
}

extension SSEClient: SSEClientProtocol {}
