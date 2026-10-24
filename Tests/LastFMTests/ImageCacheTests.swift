import Testing
import AppKit
@testable import LastFM

struct ImageCacheTests {
    @Test func testHTTPFailureAndNonImageBodiesAreNeverCached() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImageFixtureProtocol.self]
        let cache = DiskImageCache(directory: directory, session: URLSession(configuration: configuration))
        let failed = await cache.fetchAndCache(from: "https://fixture.invalid/503")
        let html = await cache.fetchAndCache(from: "https://fixture.invalid/html")
        #expect(failed == nil)
        #expect(html == nil)
        #expect(cache.cacheSize() == 0)
    }

    @Test @MainActor func testReplacingSourceClearsArtworkAndRejectsLateOldResult() async {
        let loader = ArtworkImageLoader()
        var finishOld: CheckedContinuation<URL?, Never>?
        let old = Task { await loader.load("old") { _ in
            await withCheckedContinuation { finishOld = $0 }
        } }
        while finishOld == nil { await Task.yield() }
        await loader.load("new") { _ in URL(fileURLWithPath: "/new.png") }
        #expect(loader.fileURL?.path == "/new.png")
        finishOld?.resume(returning: URL(fileURLWithPath: "/old.png"))
        await old.value
        #expect(loader.fileURL?.path == "/new.png")
        await loader.load(nil) { _ in Issue.record("Empty source must not fetch"); return nil }
        #expect(loader.fileURL == nil)
    }
}

private final class ImageFixtureProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let status = request.url!.path == "/503" ? 503 : 200
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "text/html"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("<html>upstream error</html>".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
