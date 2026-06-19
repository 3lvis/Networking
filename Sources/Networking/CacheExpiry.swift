import Foundation

// Holds the disk cache's TTL and answers "is this entry too old?". The clock is the file's modification
// date (persisted by the filesystem, re-warmed on a disk hit), so there's no in-memory access map and no
// manifest to keep in sync. Lock-synchronized rather than an actor because the cache layer is nonisolated
// and synchronous (e.g. `imageFromCache`) — an actor would force `await` into that path.
final class CacheExpiry: @unchecked Sendable {
    private let lock = NSLock()
    private var ttlSeconds: Double

    init(ttl: Duration) {
        ttlSeconds = ttl.seconds
    }

    var ttl: Duration {
        lock.lock()
        defer { lock.unlock() }
        return .seconds(ttlSeconds)
    }

    func setTTL(_ ttl: Duration) {
        lock.lock()
        defer { lock.unlock() }
        ttlSeconds = ttl.seconds
    }

    // Cold = the file's last use (its modification date) is older than the TTL. A missing date (no file)
    // is treated as not-expired so a present-but-unreadable entry isn't dropped spuriously.
    func isExpired(fileDate: Date?) -> Bool {
        guard let fileDate else { return false }
        lock.lock()
        defer { lock.unlock() }
        return Date().timeIntervalSince(fileDate) > ttlSeconds
    }
}
