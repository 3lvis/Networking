import Foundation

// Tracks per-entry last-access for the disk cache's sliding TTL. Lock-synchronized rather than an actor
// because the cache layer is nonisolated and synchronous (e.g. `imageFromCache`) — an actor would force
// `await` into that path. It holds only an in-memory map: never persisted (no manifest to keep in sync),
// and the cached files are never touched on read.
final class CacheExpiry: @unchecked Sendable {
    private let lock = NSLock()
    private var ttlSeconds: Double
    private var lastAccess: [String: Date] = [:]

    init(ttl: Duration) {
        ttlSeconds = Self.seconds(ttl)
    }

    var ttl: Duration {
        lock.lock(); defer { lock.unlock() }
        return .seconds(ttlSeconds)
    }

    func setTTL(_ ttl: Duration) {
        lock.lock(); defer { lock.unlock() }
        ttlSeconds = Self.seconds(ttl)
    }

    func recordAccess(_ key: String) {
        lock.lock(); defer { lock.unlock() }
        lastAccess[key] = Date()
    }

    // Cold = idle beyond the TTL. `fileDate` is the on-disk fallback for an entry with no in-session
    // access record (e.g. right after launch). Unknown age (no record and no file date) → not expired.
    func isExpired(_ key: String, fileDate: Date?) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let reference = lastAccess[key] ?? fileDate else { return false }
        return Date().timeIntervalSince(reference) > ttlSeconds
    }

    func forget(_ key: String) {
        lock.lock(); defer { lock.unlock() }
        lastAccess[key] = nil
    }

    func forgetAll() {
        lock.lock(); defer { lock.unlock() }
        lastAccess.removeAll()
    }

    static func seconds(_ duration: Duration) -> Double {
        let (wholeSeconds, attoseconds) = duration.components
        return Double(wholeSeconds) + Double(attoseconds) / 1e18
    }
}
