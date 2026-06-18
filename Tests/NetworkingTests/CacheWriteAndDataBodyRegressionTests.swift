import XCTest
@testable import Networking

// Regressions for cache-write and Data-body bugs found in review; each test names the contract it guards.
final class CacheWriteAndDataBodyRegressionTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    // A `cacheName`'d download must not leave a second file under the path-derived key — only the
    // `cacheName` key is ever read, so any path-keyed file is an orphan that lingers until the TTL sweep.
    func testDownloadDoesNotWriteOrphanCacheFileUnderPathKey() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/bytes/16"
        let cacheName = "orphan-regression-key"

        try await networking.clearCache()
        try Helper.removeFileIfNeeded(networking, path: path, cacheName: nil)
        try Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)

        let result: Result<Data, NetworkingError> = await networking.downloadData(path, cacheName: cacheName)
        guard case .success = result else { return XCTFail("expected a successful download, got \(result)") }

        let orphanURL = try networking.destinationURL(for: path, cacheName: nil)
        XCTAssertFalse(
            FileManager.default.exists(at: orphanURL),
            "downloadData wrote a stray cache file under the path key that no read path uses"
        )
    }

    // The `.memory`/`.none` pure-read contracts (a read must not destroy a durable `.memoryAndFile` copy)
    // are covered deterministically — with real warm-tier eviction — in `CacheStoreTests`.

    func testDataVerbReturnsResponseBody() async {
        let networking = Networking(baseURL: "https://example.com")
        await networking.fakeGET("/payload", response: ["message": "hello"])

        let result: Result<Data, NetworkingError> = await networking.get("/payload")
        guard case let .success(data) = result else { return XCTFail("expected success, got \(result)") }

        let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        XCTAssertEqual(decoded?["message"], "hello", "a verb with T == Data must return the response body")
    }
}
