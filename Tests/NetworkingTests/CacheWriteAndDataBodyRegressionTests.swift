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

    // A read at `.memory` must not destroy the durable on-disk copy a prior `.memoryAndFile` write
    // created. Disk is the cold tier that outlives memory eviction; a pure read deleting it is data loss
    // the moment the warm tier is evicted under pressure.
    func testMemoryReadDoesNotDeleteDiskTierFromEarlierMemoryAndFileWrite() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/bytes/16"

        try await networking.clearCache()
        try Helper.removeFileIfNeeded(networking, path: path, cacheName: nil)

        let primed: Result<Data, NetworkingError> = await networking.downloadData(path, cachingLevel: .memoryAndFile)
        guard case .success = primed else { return XCTFail("expected the priming download to succeed, got \(primed)") }

        let diskURL = try networking.destinationURL(for: path, cacheName: nil)
        XCTAssertTrue(FileManager.default.exists(at: diskURL), "priming a .memoryAndFile download should write a disk copy")

        // No eviction step needed: the bug deleted the disk file unconditionally on read, so a warm hit
        // still proves it.
        let _: Result<Data, NetworkingError> = await networking.downloadData(path, cachingLevel: .memory)

        XCTAssertTrue(
            FileManager.default.exists(at: diskURL),
            "a .memory read deleted the disk copy a prior .memoryAndFile write created"
        )
    }

    // A `.none` *download* must not delete a durable disk copy a prior `.memoryAndFile` write created.
    // The verb path already bypasses the cache for `.none`, but the download path reads through
    // `objectFromCache`, which used to purge both tiers — wiping an entry deliberately cached elsewhere.
    func testNoneDownloadDoesNotDeleteDiskTierFromEarlierMemoryAndFileWrite() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/bytes/16"

        try await networking.clearCache()
        try Helper.removeFileIfNeeded(networking, path: path, cacheName: nil)

        let primed: Result<Data, NetworkingError> = await networking.downloadData(path, cachingLevel: .memoryAndFile)
        guard case .success = primed else { return XCTFail("expected the priming download to succeed, got \(primed)") }

        let diskURL = try networking.destinationURL(for: path, cacheName: nil)
        XCTAssertTrue(FileManager.default.exists(at: diskURL), "priming a .memoryAndFile download should write a disk copy")

        let _: Result<Data, NetworkingError> = await networking.downloadData(path, cachingLevel: .none)

        XCTAssertTrue(
            FileManager.default.exists(at: diskURL),
            "a .none download deleted the disk copy a prior .memoryAndFile write created"
        )
    }

    func testDataVerbReturnsResponseBody() async {
        let networking = Networking(baseURL: "https://example.com")
        await networking.fakeGET("/payload", response: ["message": "hello"])

        let result: Result<Data, NetworkingError> = await networking.get("/payload")
        guard case let .success(data) = result else { return XCTFail("expected success, got \(result)") }

        let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        XCTAssertEqual(decoded?["message"], "hello", "a verb with T == Data must return the response body")
    }
}
