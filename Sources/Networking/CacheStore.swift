import CryptoKit
import Foundation

// Owns both cache tiers: the in-memory `NSCache` (warm, pressure-evicted by iOS) over the on-disk shard
// layout (cold, durable). A non-actor, synchronous type so the nonisolated cache reads
// (`imageFromCache`/`dataFromCache`) stay synchronous; thread-safety comes from `NSCache` (thread-safe),
// `CacheExpiry` (lock-synchronized), and a static lock serializing whole-folder mutations against the
// background sweep. Keyed by an already-resolved resource string — composing a key from baseURL + path is
// the networking layer's job, not the store's.
final class CacheStore: @unchecked Sendable {
    let memory: NSCache<AnyObject, AnyObject>
    let expiry: CacheExpiry
    let folderName: String

    init(memory: NSCache<AnyObject, AnyObject>, ttl: Duration, folderName: String) {
        self.memory = memory
        self.expiry = CacheExpiry(ttl: ttl)
        self.folderName = folderName
    }

    var ttl: Duration { expiry.ttl }
    func setTTL(_ ttl: Duration) { expiry.setTTL(ttl) }

    // MARK: - Layout

    /// The on-disk URL for a resolved resource key, laid out under `folderName/<shard>/<file>`. Creates the
    /// shard directory if needed.
    func destinationURL(forResource resource: String) throws -> URL {
        let component = Self.filesystemSafeComponent(resource.replacingOccurrences(of: "/", with: "-"))
        // Shard the cache directory by a hash of the key so the per-launch sweep is O(N / shardCount), not
        // O(N). Always sharded — one uniform layout, no migration or size threshold (see `sweepExpired`).
        let folderPath = "\(folderName)/\(Self.shardName(for: component))"
        let finalPath = "\(folderPath)/\(component)"

        guard let url = URL(string: finalPath),
            let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        else {
            throw NSError(
                domain: folderName, code: 9999,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't build a cache URL for: \(finalPath)"])
        }

        let folderURL = cachesURL.appendingPathComponent(URL(string: folderPath)!.absoluteString)
        if FileManager.default.exists(at: folderURL) == false {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        }
        return cachesURL.appendingPathComponent(url.absoluteString)
    }

    static let shardCount = 16

    // One hex-nibble shard derived from the key's hash; stable for a given key so reads and writes agree.
    static func shardName(for component: String) -> String {
        let byte = Array(SHA256.hash(data: Data(component.utf8))).first ?? 0
        return String(Int(byte) % shardCount, radix: 16)
    }

    // A filesystem path component caps at 255 bytes, which a long URL would overflow. Keep a readable,
    // byte-bounded prefix and append a hash of the full name so distinct URLs still get distinct files.
    static func filesystemSafeComponent(_ name: String) -> String {
        let maxBytes = 255
        guard name.utf8.count > maxBytes else { return name }
        let hash = SHA256.hash(data: Data(name.utf8)).map { String(format: "%02x", $0) }.joined()
        let prefixBudget = maxBytes - hash.count - 1
        var prefix = ""
        var byteCount = 0
        for character in name {
            let width = String(character).utf8.count
            if byteCount + width > prefixBudget { break }
            prefix.append(character)
            byteCount += width
        }
        return "\(prefix)-\(hash)"
    }

    // MARK: - Read

    /// A pure read: serve from the warm tier, falling back to a non-expired disk entry (which re-warms both
    /// tiers). Never mutates a tier except to drop an entry it finds expired. `.memory`/`.none` never touch
    /// disk, so a read can't destroy a durable copy written at `.memoryAndFile`.
    func object(forResource resource: String, level: Networking.CachingLevel, asImage: Bool) throws -> Any? {
        let destinationURL = try destinationURL(forResource: resource)
        let key = destinationURL.absoluteString
        switch level {
        case .memory:
            return memory.object(forKey: key as AnyObject)
        case .memoryAndFile:
            // Memory is the warm tier — a memory hit is served without touching the disk (the NSCache
            // absorbs repeat reads, so the file's mtime is only re-warmed on a memory miss, below).
            if let object = memory.object(forKey: key as AnyObject) {
                return object
            } else if FileManager.default.exists(at: destinationURL) {
                let fileDate = try? destinationURL.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate
                if expiry.isExpired(fileDate: fileDate) {
                    try FileManager.default.remove(at: destinationURL)
                    return nil
                }

                // The file can vanish between the exists() check above and this read — the background
                // sweep runs concurrently and doesn't share a lock with reads — so a read failure is a
                // cache miss, not a crash.
                guard let data = FileManager.default.contents(atPath: destinationURL.path) else { return nil }
                let returnedObject: Any? = asImage ? Image(data: data) : data
                if let returnedObject {
                    memory.setObject(returnedObject as AnyObject, forKey: key as AnyObject)
                    // Re-warm: bump the file's mtime so an entry in active use never expires. Only happens
                    // on a memory miss, so it's ~once per entry per launch — no explicit debounce needed.
                    try? FileManager.default.setAttributes(
                        [.modificationDate: Date()], ofItemAtPath: destinationURL.path)
                }

                return returnedObject
            } else {
                return nil
            }
        case .none:
            return nil
        }
    }

    // MARK: - Write

    func storeData(_ data: Data?, forResource resource: String, level: Networking.CachingLevel) throws {
        let destinationURL = try destinationURL(forResource: resource)
        let key = destinationURL.absoluteString

        if let returnedData = data, returnedData.count > 0 {
            switch level {
            case .memory:
                memory.setObject(returnedData as AnyObject, forKey: key as AnyObject)
            case .memoryAndFile:
                _ = try returnedData.write(to: destinationURL, options: [.atomic])
                memory.setObject(returnedData as AnyObject, forKey: key as AnyObject)
            case .none:
                break
            }
            // The disk write itself sets a fresh mtime — that *is* the entry's last-use timestamp.
        } else {
            memory.removeObject(forKey: key as AnyObject)
        }
    }

    @discardableResult
    func storeImage(data: Data?, forResource resource: String, level: Networking.CachingLevel) throws -> Image? {
        let destinationURL = try destinationURL(forResource: resource)
        let key = destinationURL.absoluteString

        var image: Image?
        if let data = data, let nonOptionalImage = Image(data: data), data.count > 0 {
            switch level {
            case .memory:
                memory.setObject(nonOptionalImage, forKey: key as AnyObject)
            case .memoryAndFile:
                _ = try data.write(to: destinationURL, options: [.atomic])
                memory.setObject(nonOptionalImage, forKey: key as AnyObject)
            case .none:
                break
            }
            image = nonOptionalImage
        } else {
            memory.removeObject(forKey: key as AnyObject)
        }

        return image
    }

    // MARK: - Clear & sweep

    // Serializes whole-folder mutations of the shared cache directory so the background sweep (which
    // creates the folder + writes its cursor) can't race a clear.
    static let mutationLock = NSLock()
    static let sweepCursorFileName = ".sweep-shard"

    /// Empties **both** tiers (clearing only one would leave the other serving deleted data). Scoped to the
    /// networking folder; unrelated files in Caches are untouched.
    func clear() throws {
        memory.removeAllObjects()
        Self.mutationLock.lock()
        defer { Self.mutationLock.unlock() }
        guard let folderURL = Self.folderURL(named: folderName) else { return }
        if FileManager.default.exists(at: folderURL) {
            _ = try FileManager.default.remove(at: folderURL)
        }
    }

    private static func folderURL(named folderName: String) -> URL? {
        guard let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return cachesURL.appendingPathComponent(URL(string: folderName)!.absoluteString)
    }

    // Deletes expired files from **one** shard per call (rotated via a tiny cursor file), so each launch's
    // sweep is O(N / shardCount) and everything gets visited over `shardCount` launches. Age is judged by
    // the file's modification date. Best-effort and off the request path.
    func sweepExpired() {
        Self.mutationLock.lock()
        defer { Self.mutationLock.unlock() }
        guard let domainURL = Self.folderURL(named: folderName) else { return }
        let now = Date()
        let maxAge = expiry.ttl.seconds

        let cursorURL = domainURL.appendingPathComponent(Self.sweepCursorFileName)
        let cursor =
            (try? String(contentsOf: cursorURL, encoding: .utf8)).flatMap {
                Int($0.trimmingCharacters(in: .whitespacesAndNewlines))
            } ?? 0
        let shardURL = domainURL.appendingPathComponent(String(cursor % Self.shardCount, radix: 16))

        if let files = try? FileManager.default.contentsOfDirectory(
            at: shardURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [])
        {
            for file in files {
                guard
                    let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey])
                        .contentModificationDate
                else { continue }
                if now.timeIntervalSince(modified) > maxAge {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }

        // Pre-sharding versions wrote files directly under the domain root; clear those strays (the cursor
        // file and the shard subdirectories stay).
        if let rootEntries = try? FileManager.default.contentsOfDirectory(
            at: domainURL, includingPropertiesForKeys: [.isRegularFileKey], options: [])
        {
            for entry in rootEntries where entry.lastPathComponent != Self.sweepCursorFileName {
                if (try? entry.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                    try? FileManager.default.removeItem(at: entry)
                }
            }
        }

        try? FileManager.default.createDirectory(at: domainURL, withIntermediateDirectories: true)
        try? String(cursor &+ 1).write(to: cursorURL, atomically: true, encoding: .utf8)
    }
}
