import Foundation
import Testing
@testable import OpenCodeClient

struct HTTPStatusAcceptanceTests {
    @Test func deleteSessionRejectsRedirectAndNotModified() async throws {
        try await expectRejected(
            status: 302,
            body: "moved",
            call: { try await $0.deleteSession(sessionID: "s1") }
        )
        try await expectRejected(
            status: 304,
            body: "cached",
            call: { try await $0.deleteSession(sessionID: "s1") }
        )
    }

    @Test func deleteSessionRejectsClientAndServerErrors() async throws {
        try await expectRejected(
            status: 404,
            body: "missing",
            call: { try await $0.deleteSession(sessionID: "s1") }
        )
        try await expectRejected(
            status: 500,
            body: "down",
            call: { try await $0.deleteSession(sessionID: "s1") }
        )
    }

    @Test func deleteSessionAcceptsEmptyBodyAndBooleanJSON() async throws {
        try await expectSuccess(status: 204, body: Data()) {
            try await $0.deleteSession(sessionID: "s1")
        }
        try await expectSuccess(status: 200, body: Data("\n".utf8)) {
            try await $0.deleteSession(sessionID: "s1")
        }
        try await expectSuccess(status: 200, body: Data("true".utf8)) {
            try await $0.deleteSession(sessionID: "s1")
        }
        try await expectSuccess(status: 200, body: Data("false".utf8)) {
            try await $0.deleteSession(sessionID: "s1")
        }
    }

    @Test func deleteSessionNonBooleanJSONIsDecodeError() async {
        let client = makeClient(status: 200, body: Data("{\"ok\":true}".utf8))
        do {
            try await client.deleteSession(sessionID: "s1")
            Issue.record("expected decode failure")
        } catch {
            expectDecodeNotHTTP(error)
        }
    }

    @Test func replyQuestionRejectsNon2xxAndAcceptsContractBody() async throws {
        try await expectRejected(status: 302, body: "moved") {
            try await $0.replyQuestion(requestID: "q1", answers: [["a"]])
        }
        try await expectRejected(status: 400, body: "bad answers") {
            try await $0.replyQuestion(requestID: "q1", answers: [["a"]])
        }
        try await expectRejected(status: 503, body: "unavailable") {
            try await $0.replyQuestion(requestID: "q1", answers: [["a"]])
        }
        try await expectSuccess(status: 200, body: Data()) {
            try await $0.replyQuestion(requestID: "q1", answers: [["a"]])
        }
        try await expectSuccess(status: 200, body: Data("true".utf8)) {
            try await $0.replyQuestion(requestID: "q1", answers: [["a"]])
        }
    }

    @Test func rejectQuestionRejectsNon2xxAndAcceptsContractBody() async throws {
        try await expectRejected(status: 304, body: "cached") {
            try await $0.rejectQuestion(requestID: "q1")
        }
        try await expectRejected(status: 409, body: "conflict") {
            try await $0.rejectQuestion(requestID: "q1")
        }
        try await expectRejected(status: 500, body: "down") {
            try await $0.rejectQuestion(requestID: "q1")
        }
        try await expectSuccess(status: 204, body: Data()) {
            try await $0.rejectQuestion(requestID: "q1")
        }
        try await expectSuccess(status: 200, body: Data("false".utf8)) {
            try await $0.rejectQuestion(requestID: "q1")
        }
    }

    @Test func promptAsyncRequires204() async throws {
        try await expectSuccess(status: 204, body: Data()) {
            try await $0.promptAsync(sessionID: "s1", messageID: "m1", text: "hi", model: nil, directory: nil)
        }
        try await expectRejected(status: 200, body: "accepted") {
            try await $0.promptAsync(sessionID: "s1", messageID: "m1", text: "hi", model: nil, directory: nil)
        }
        try await expectRejected(status: 302, body: "moved") {
            try await $0.promptAsync(sessionID: "s1", messageID: "m1", text: "hi", model: nil, directory: nil)
        }
        try await expectRejected(status: 500, body: "down") {
            try await $0.promptAsync(sessionID: "s1", messageID: "m1", text: "hi", model: nil, directory: nil)
        }
    }

    @Test func abortRequires200() async throws {
        try await expectSuccess(status: 200, body: Data("true".utf8)) {
            try await $0.abort(sessionID: "s1")
        }
        try await expectRejected(status: 204, body: "") {
            try await $0.abort(sessionID: "s1")
        }
        try await expectRejected(status: 302, body: "moved") {
            try await $0.abort(sessionID: "s1")
        }
        try await expectRejected(status: 500, body: "down") {
            try await $0.abort(sessionID: "s1")
        }
    }

    @Test func respondPermissionRequires200AndKeepsBody() async throws {
        try await expectSuccess(status: 200, body: Data("true".utf8)) {
            try await $0.respondPermission(sessionID: "s1", permissionID: "p1", response: .once)
        }
        try await expectRejected(status: 201, body: "created") {
            try await $0.respondPermission(sessionID: "s1", permissionID: "p1", response: .once)
        }
        try await expectRejected(status: 403, body: "denied") {
            try await $0.respondPermission(sessionID: "s1", permissionID: "p1", response: .reject)
        }
    }

    @Test(arguments: [302, 400, 403, 409, 500]) @MainActor
    func permissionHTTPFailurePreservesPendingAndRevision(status: Int) async {
        // Exercise the real URLSession/APIClient boundary, not a throwing mock.
        let client = makeClient(status: status, body: Data("rejected".utf8))
        let state = makeIsolatedAppState(apiClient: client)
        let permission = PendingPermission(sessionID: "child", permissionID: "p1", permission: "edit",
                                           patterns: [], allowAlways: false, tool: nil, description: "Synthetic request")
        state.pendingPermissions = [permission]
        await state.respondPermission(permission, response: .once)
        #expect(state.pendingPermissions.map(\.id) == [permission.id])
        #expect(state.permissionRevision == 0)
        #expect(state.connectionError != nil)
    }

    @Test func healthDistinguishesHTTPErrorFromDecodeError() async throws {
        try await expectSuccess(status: 200, body: Data("{\"healthy\":true}".utf8)) {
            let health = try await $0.health()
            #expect(health.healthy)
        }

        let invalid = makeClient(status: 200, body: Data("not-json".utf8))
        do {
            _ = try await invalid.health()
            Issue.record("expected decode failure")
        } catch {
            expectDecodeNotHTTP(error)
        }

        try await expectRejected(status: 302, body: "<html>moved</html>") {
            _ = try await $0.health()
        }
        try await expectRejected(status: 500, body: "down") {
            _ = try await $0.health()
        }
    }

    @Test func nonHTTPResponseIsHTTPErrorWithBody() async {
        let client = makeClient(status: 0, body: Data("not-http".utf8), http: false)
        do {
            _ = try await client.health()
            Issue.record("expected non-HTTP failure")
        } catch {
            expectHTTP(error, status: 0, body: "not-http")
        }
    }

    @Test func configureKeepsInjectedSession() async throws {
        let name = stubHost()
        OfflineHTTPRegistry.set(host: name, stub: OfflineHTTPStub(status: 200, body: Data("{\"healthy\":true}".utf8)))
        defer { OfflineHTTPRegistry.remove(host: name) }
        let client = APIClient(baseURL: "http://\(name)", session: makeSession())
        await client.configure(baseURL: "http://\(name)", username: nil, password: nil)
        let health = try await client.health()
        #expect(health.healthy)
    }

    /// A form that arrives over the event stream has to be answerable: the app
    /// shows the options by their label, and the server wants their value.
    @Test func aFormFromTheEventStreamIsAnsweredWithTheOptionValues() async throws {
        let name = stubHost()
        OfflineHTTPRegistry.set(host: name, stub: OfflineHTTPStub(status: 204, body: Data()))
        defer { OfflineHTTPRegistry.remove(host: name) }
        let client = APIClient(baseURL: "http://\(name)", session: makeSession())
        await client.configure(baseURL: "http://\(name)", username: nil, password: nil, generation: .v2)

        // The form as the event stream delivers it: the labels the app shows
        // and the values the server expects.
        await client.rememberFormReplyTable(from: [
            "id": "frm_1",
            "sessionID": "ses_1",
            "fields": [
                [
                    "key": "color",
                    "type": "string",
                    "options": [
                        ["value": "r", "label": "Red"],
                        ["value": "b", "label": "Blue"],
                    ],
                ],
            ],
        ])

        try await client.replyQuestion(requestID: "frm_1", answers: [["Red"]])

        let requests = OfflineHTTPRegistry.requests(for: name)
        let reply = requests.first { $0.path.contains("/form/frm_1/reply") }
        #expect(reply?.method == "POST")
        #expect(reply?.path == "/api/session/ses_1/form/frm_1/reply")
        let body = try #require(reply?.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let answer = try #require(object["answer"] as? [String: Any])
        #expect(answer["color"] as? String == "r")
    }
}

private struct OfflineHTTPStub {
    var status: Int
    var body: Data
    var http: Bool = true
}

private enum OfflineHTTPRegistry {
    static let lock = NSLock()
    static var stubs: [String: OfflineHTTPStub] = [:]
    /// The requests the stub answered, so a test can assert what was sent.
    static var recorded: [String: [(method: String, path: String, body: Data)]] = [:]

    static func set(host: String, stub: OfflineHTTPStub) {
        lock.lock()
        stubs[host] = stub
        lock.unlock()
    }

    static func stub(for host: String) -> OfflineHTTPStub? {
        lock.lock()
        defer { lock.unlock() }
        return stubs[host]
    }

    static func record(host: String, method: String, path: String, body: Data) {
        lock.lock()
        recorded[host, default: []].append((method: method, path: path, body: body))
        lock.unlock()
    }

    static func requests(for host: String) -> [(method: String, path: String, body: Data)] {
        lock.lock()
        defer { lock.unlock() }
        return recorded[host] ?? []
    }

    static func remove(host: String) {
        lock.lock()
        stubs.removeValue(forKey: host)
        recorded.removeValue(forKey: host)
        lock.unlock()
    }
}

final class RefuseRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

@objc(W10OfflineHTTPProtocol)
final class OfflineHTTPProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.hasPrefix("w10-stub-") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let host = url.host, let stub = OfflineHTTPRegistry.stub(for: host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        OfflineHTTPRegistry.record(
            host: host,
            method: request.httpMethod ?? "GET",
            path: url.path,
            body: Self.bodyData(of: request)
        )
        let response: URLResponse
        if stub.http {
            guard let http = HTTPURLResponse(
                url: url,
                statusCode: stub.status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            response = http
        } else {
            response = URLResponse(
                url: url,
                mimeType: nil,
                expectedContentLength: stub.body.count,
                textEncodingName: nil
            )
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// The body of the request.
    ///
    /// A URL session hands a body to a protocol as a stream, so the bytes
    /// have to be read from there rather than from `httpBody`.
    private static func bodyData(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

private func stubHost() -> String {
    "w10-stub-\(UUID().uuidString.lowercased()).invalid"
}

private func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [OfflineHTTPProtocol.self]
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    config.urlCache = nil
    config.timeoutIntervalForRequest = 2
    config.timeoutIntervalForResource = 2
    config.waitsForConnectivity = false
    return URLSession(configuration: config, delegate: RefuseRedirect(), delegateQueue: nil)
}

private func makeClient(status: Int, body: Data, http: Bool = true) -> APIClient {
    let name = stubHost()
    OfflineHTTPRegistry.set(host: name, stub: OfflineHTTPStub(status: status, body: body, http: http))
    return APIClient(baseURL: "http://\(name)", session: makeSession())
}

private func expectHTTP(_ error: Error, status: Int, body: String) {
    guard case APIError.httpError(let code, let data) = error else {
        Issue.record("expected APIError.httpError, got \(error)")
        return
    }
    #expect(code == status)
    #expect(String(data: data, encoding: .utf8) == body)
    #expect(!(error is DecodingError))
}

private func expectDecodeNotHTTP(_ error: Error) {
    #expect(error is DecodingError)
    if case APIError.httpError = error {
        Issue.record("decode failure was reported as HTTP error")
    }
}

private func expectRejected(
    status: Int,
    body: String,
    call: (APIClient) async throws -> Void
) async throws {
    let client = makeClient(status: status, body: Data(body.utf8))
    do {
        try await call(client)
        Issue.record("expected HTTP \(status) to fail")
    } catch {
        expectHTTP(error, status: status, body: body)
    }
}

private func expectSuccess(
    status: Int,
    body: Data,
    call: (APIClient) async throws -> Void
) async throws {
    let client = makeClient(status: status, body: body)
    try await call(client)
}
