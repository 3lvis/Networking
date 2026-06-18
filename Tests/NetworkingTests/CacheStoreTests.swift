import XCTest
@testable import Networking

// Unit tests for the cache store itself — layout, the sliding-TTL expiry, the pure-read contracts, and
// clear — exercised directly rather than through the `Networking` actor. The store keys on an
// already-resolved resource string, so these pass keys verbatim (no baseURL/path composition).
final class CacheStoreTests: XCTestCase {
    private let folderName = "com.3lvis.networking.cachestoretests"

    private func makeStore(ttl: Duration = .seconds(7 * 24 * 60 * 60)) throws -> (store: CacheStore, memory: NSCache<AnyObject, AnyObject>) {
        let memory = NSCache<AnyObject, AnyObject>()
        let store = CacheStore(memory: memory, ttl: ttl, folderName: folderName)
        try store.clear()
        return (store, memory)
    }

    override func tearDown() {
        try? CacheStore(memory: NSCache(), ttl: .seconds(1), folderName: folderName).clear()
        super.tearDown()
    }

    // A resource key longer than the filesystem's 255-byte filename limit still round-trips, via the
    // hashed-filename fallback.
    func testLongResourceKeyRoundTripsViaHashedFilename() throws {
        let (store, _) = try makeStore()
        let resource = "http://example.com/" + String(repeating: "a", count: 300)
        let payload = Data("payload".utf8)

        try store.storeData(payload, forResource: resource, level: .memoryAndFile)
        let cached = try store.object(forResource: resource, level: .memoryAndFile, asImage: false) as? Data
        XCTAssertEqual(cached, payload)
    }

    // An entry idle beyond the TTL is cold (judged by the file's mtime): dropped and reported as a miss.
    func testColdDiskEntryExpiresOnRead() throws {
        let (store, memory) = try makeStore(ttl: .seconds(60))
        let resource = "http://example.com/cold-entry"
        try store.storeData(Data("stale".utf8), forResource: resource, level: .memoryAndFile)

        let url = try store.destinationURL(forResource: resource)
        memory.removeObject(forKey: url.absoluteString as AnyObject)  // force the disk path
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -120)], ofItemAtPath: url.path)

        XCTAssertNil(
            try store.object(forResource: resource, level: .memoryAndFile, asImage: false),
            "an entry idle beyond the TTL is expired on read"
        )
    }

    // A disk hit re-warms the file's mtime, so an entry in active use never expires (sliding TTL).
    func testDiskHitReWarmsFileDate() throws {
        let (store, memory) = try makeStore(ttl: .seconds(60))
        let resource = "http://example.com/warm-entry"
        try store.storeData(Data("fresh".utf8), forResource: resource, level: .memoryAndFile)

        let url = try store.destinationURL(forResource: resource)
        memory.removeObject(forKey: url.absoluteString as AnyObject)  // force the disk path
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -30)], ofItemAtPath: url.path)

        XCTAssertNotNil(try store.object(forResource: resource, level: .memoryAndFile, asImage: false))
        let mtime = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate!
        XCTAssertLessThan(Date().timeIntervalSince(mtime), 5, "the disk hit should have re-warmed the mtime to ~now")
    }

    // (No memory-hit-rewarm test: NSCache can evict at any time, so a memory hit can't be forced
    // deterministically — on eviction the read becomes the disk hit covered above.)

    // A `.memory` read serves the warm tier only and must NOT delete the durable disk copy — even after the
    // warm tier is evicted (which iOS does under memory pressure), so the entry survives the next read.
    func testMemoryReadNeverDeletesTheDiskTier() throws {
        let (store, memory) = try makeStore()
        let resource = "http://example.com/durable-memory"
        try store.storeData(Data("durable".utf8), forResource: resource, level: .memoryAndFile)
        let url = try store.destinationURL(forResource: resource)

        memory.removeAllObjects()  // simulate iOS evicting the warm tier
        _ = try store.object(forResource: resource, level: .memory, asImage: false)

        XCTAssertTrue(FileManager.default.exists(at: url), "a .memory read deleted the durable disk copy")
        XCTAssertEqual(
            try store.object(forResource: resource, level: .memoryAndFile, asImage: false) as? Data,
            Data("durable".utf8),
            "the disk copy should still be readable after the .memory read"
        )
    }

    // `.none` reports a miss without touching either tier, so it can't destroy an entry cached elsewhere.
    func testNoneReadNeverDeletesTheDiskTier() throws {
        let (store, _) = try makeStore()
        let resource = "http://example.com/durable-none"
        try store.storeData(Data("durable".utf8), forResource: resource, level: .memoryAndFile)
        let url = try store.destinationURL(forResource: resource)

        XCTAssertNil(try store.object(forResource: resource, level: .none, asImage: false))
        XCTAssertTrue(FileManager.default.exists(at: url), "a .none read deleted the durable disk copy")
    }

    // clear() empties both tiers — the bug the old disk-only cleanup left behind was memory still serving
    // deleted data.
    func testClearEmptiesBothTiers() throws {
        let (store, _) = try makeStore()
        let resource = "http://example.com/cached"
        try store.storeData(Data("hi".utf8), forResource: resource, level: .memoryAndFile)
        XCTAssertNotNil(try store.object(forResource: resource, level: .memoryAndFile, asImage: false))

        try store.clear()

        XCTAssertNil(try store.object(forResource: resource, level: .memoryAndFile, asImage: false))
    }
}
