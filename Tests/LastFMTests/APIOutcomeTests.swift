import Testing
import Foundation
@testable import LastFM

final class APIAuditURLProtocol: URLProtocol {
    static let lock = NSLock()
    static var handler: ((URLRequest) -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); let handler = Self.handler; Self.lock.unlock()
        guard let handler else { return client!.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)) }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized)
struct APIOutcomeTests {
    private func response(_ json: String, status: Int = 200) {
        APIAuditURLProtocol.handler = { _ in (status, Data(json.utf8)) }
    }
    private func service() -> ScrobbleService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [APIAuditURLProtocol.self]
        return ScrobbleService(apiKey: "fixture", apiSecret: "fixture-secret", session: URLSession(configuration: config))
    }
    private func submit() async throws {
        try await service().scrobble(track: "A+B", artist: "Fixture", album: "", duration: 180, timestamp: 100, sessionKey: "fixture-session")
    }
    @Test func testIgnoredScrobbleDoesNotReturnSuccess() async {
        response(##"{"scrobbles":{"@attr":{"accepted":"0","ignored":"1"},"scrobble":{"ignoredMessage":{"code":"1","#text":"Artist ignored"}}}}"##)
        do { try await submit(); Issue.record("Ignored scrobble was incorrectly accepted") } catch {}
    }
    @Test func testMalformedSuccessBodyDoesNotReturnSuccess() async {
        response("{}")
        do { try await submit(); Issue.record("Missing acceptance must not count as success") } catch {}
    }
    @Test func testHTTPFailureDoesNotReturnSuccess() async {
        response("{}", status: 503)
        do { try await submit(); Issue.record("HTTP 503 must not count as success") } catch {}
    }
    @Test func testPositiveStringAcceptanceSucceeds() async throws {
        response(##"{"scrobbles":{"@attr":{"accepted":"1","ignored":"0"},"scrobble":{"ignoredMessage":{"code":"0","#text":""}}}}"##)
        try await submit()
    }
    @Test func testLoveInspectsAPIErrorInHTTP200() async {
        response(#"{"error":10,"message":"Invalid API key"}"#)
        do {
            try await service().loveTrack(track: "A", artist: "Fixture", sessionKey: "fixture-session")
            Issue.record("Love silently ignored the API error")
        } catch {}
    }
    @Test func testUnloveInspectsAPIErrorInHTTP200() async {
        response(#"{"error":9,"message":"Invalid session key"}"#)
        do {
            try await service().unloveTrack(track: "A", artist: "Fixture", sessionKey: "fixture-session")
            Issue.record("Unlove silently ignored the API error")
        } catch {}
    }
    @Test func testNowPlayingRequiresExpectedSuccessShape() async {
        response("{}")
        do {
            _ = try await service().updateNowPlaying(track: "A", artist: "Fixture", album: "", duration: 180, sessionKey: "fixture-session")
            Issue.record("Malformed now-playing response silently succeeded")
        } catch {}
    }
    @Test func testTokenResponsePreservesPermanentAPIError() async {
        response(#"{"error":10,"message":"Invalid API key"}"#)
        do {
            _ = try await service().getRequestToken()
            Issue.record("Expected API rejection")
        } catch ScrobbleError.apiError(let code, _) { #expect(code == 10) }
        catch { Issue.record("Lost the permanent API error: \(error)") }
    }
    @Test func testExistingSessionResolvesItsActualOwner() async throws {
        response(#"{"user":{"name":"ActualAccount"}}"#)
        let name = try await service().getAuthenticatedUsername(sessionKey: "fixture-session")
        #expect(name == "ActualAccount")
    }
    @Test func testAuthenticatedSessionRetainsAccountName() async throws {
        response(#"{"session":{"key":"fixture-session","name":"ActualAccount","subscriber":0}}"#)
        let session = try await service().getAuthenticatedSession(token: "fixture-token")
        #expect(session.key == "fixture-session")
        #expect(session.name == "ActualAccount")
    }
    @Test func testDefaultClientUsesCredentialsSavedAfterInitialization() async throws {
        let domain = "LastFMAPIStoreTest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = CredentialStore(defaults: defaults, backend: CredentialsMemoryBackend())
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [APIAuditURLProtocol.self]
        let client = ScrobbleService(session: URLSession(configuration: config), credentialStore: store)
        try store.saveCredentials(apiKey: "updated-key", apiSecret: "updated-secret")
        APIAuditURLProtocol.handler = { request in
            var data = request.httpBody ?? Data()
            if data.isEmpty, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    data.append(contentsOf: buffer.prefix(count))
                }
            }
            let form = String(data: data, encoding: .utf8) ?? ""
            #expect(form.contains("api_key=updated-key"))
            #expect(form.contains("track=A%2BB"))
            return (200, Data("{}".utf8))
        }
        try await client.loveTrack(track: "A+B", artist: "Fixture", sessionKey: "fixture-session")
    }

}
