import CryptoKit
import Foundation
import os.log

public extension Int {

    var statusCodeType: Networking.StatusCodeType {
        switch self {
        case URLError.cancelled.rawValue:
            return .cancelled
        case 100 ..< 200:
            return .informational
        case 200 ..< 300:
            return .successful
        case 300 ..< 400:
            return .redirection
        case 400 ..< 500:
            return .clientError
        case 500 ..< 600:
            return .serverError
        default:
            return .unknown
        }
    }
}

public actor Networking {
    static let domain = "com.3lvis.networking"

    enum RequestType: String {
        case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
    }

    enum SessionTaskType: String {
        case data, upload, download
    }

    enum ResponseType {
        case json
        case data
        case image

        var accept: String? {
            switch self {
            case .json:
                return "application/json"
            default:
                return nil
            }
        }
    }

    public enum StatusCodeType {
        case informational, successful, redirection, clientError, serverError, cancelled, unknown
    }

    let baseURL: String
    var fakeRequests = [RequestType: [String: FakeRequest]]()
    var token: String?
    var authorizationHeaderValue: String?
    var authorizationHeaderKey = "Authorization"
    fileprivate var configuration: URLSessionConfiguration
    nonisolated(unsafe) let cache: NSCache<AnyObject, AnyObject>
    let cacheExpiry: CacheExpiry

    private var streamContinuations: [UUID: AsyncStream<NetworkingEvent>.Continuation] = [:]

    /// A stream of observability events — one `.started` then one `.completed` per request. Each call
    /// returns its own multicast stream; the buffer keeps the newest 256 events for a slow consumer.
    public func events() -> AsyncStream<NetworkingEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: NetworkingEvent.self, bufferingPolicy: .bufferingNewest(256))
        let id = UUID()
        streamContinuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        return stream
    }

    private func removeContinuation(_ id: UUID) {
        streamContinuations[id] = nil
    }

    func emit(_ event: NetworkingEvent) {
        for continuation in streamContinuations.values {
            continuation.yield(event)
        }
    }

    /// Which requests the built-in diagnostics cover. Gates *only* the built-in logging; `events()`
    /// always carries full structured events regardless.
    public var logLevel: LogLevel = .failures

    public func setLogLevel(_ level: LogLevel) {
        self.logLevel = level
    }

    private static let defaultRedactsLogs: Bool = {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }()

    /// Whether the built-in **logs** redact sensitive content — the request/response body lines *and* the
    /// `redactedHeaderFields` header values. Defaults to redacting in release and showing everything in
    /// debug. Governs the *logs* only — `events()` always carries the real headers.
    public var redactsLogs = Networking.defaultRedactsLogs

    public func setRedactsLogs(_ redacts: Bool) {
        self.redactsLogs = redacts
    }

    /// When set, the built-in diagnostics are *also* appended to this file as plain text — so a CLI or
    /// headless/agent run (where `os.Logger` isn't visible in stdout) can read what happened. Defaults
    /// from the `NETWORKING_LOG_FILE` environment variable, so logs can be captured with no code change.
    public var logFileURL: URL?

    public func setLogFileURL(_ url: URL?) {
        self.logFileURL = url
    }

    func record(_ message: String, level: OSLogType) {
        guard logLevel != .none else { return }
        logger.log(level: level, "\(message, privacy: .public)")
        appendToLogFile(message)
    }

    private func appendToLogFile(_ message: String) {
        guard let logFileURL else { return }
        let entry = "\(Date().ISO8601Format()) \(message)\n"
        guard let data = entry.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: logFileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: logFileURL, options: .atomic)
        }
    }

    /// Header field names whose values are replaced with `<redacted>` in the built-in **logs** when
    /// `redactsLogs` is on. Matched case-insensitively; the active authorization header key is always
    /// included.
    var redactedHeaderFields: Set<String> = ["Authorization", "Cookie", "Set-Cookie"]

    public func setRedactedHeaderFields(_ fields: Set<String>) {
        self.redactedHeaderFields = fields
    }

    func redactedHeaders(_ headers: [String: String]) -> [String: String] {
        let redacted = Set(redactedHeaderFields.union([authorizationHeaderKey]).map { $0.lowercased() })
        return headers.reduce(into: [String: String]()) { result, pair in
            result[pair.key] = redacted.contains(pair.key.lowercased()) ? "<redacted>" : pair.value
        }
    }

    nonisolated let boundary = String(format: "com.elvisnunez.networking.%08x%08x", arc4random(), arc4random())

    lazy var session: URLSession = {
        URLSession(configuration: self.configuration)
    }()

    public enum CachingLevel {
        case memory
        case memoryAndFile
        case none
    }

    private static let defaultLogger = Logger(subsystem: "com.elvisnunez.networking", category: "network")

    let logger: Logger

    /// How long an unused on-disk cache entry survives. A disk read or write re-warms the entry (its
    /// clock is the file's modification date), so something in active use never expires; only entries
    /// idle past `cacheTTL` are swept. Default 7 days. Memory (`NSCache`) is the warm tier, pressure-evicted.
    nonisolated public var cacheTTL: Duration { cacheExpiry.ttl }

    public func setCacheTTL(_ ttl: Duration) {
        cacheExpiry.setTTL(ttl)
    }

    public init(baseURL: String = "", configuration: URLSessionConfiguration = .default, cache: NSCache<AnyObject, AnyObject>? = nil, logger: Logger? = nil, cacheTTL: Duration = .seconds(7 * 24 * 60 * 60)) {
        self.baseURL = baseURL
        self.configuration = configuration
        self.cache = cache ?? NSCache()
        self.cacheExpiry = CacheExpiry(ttl: cacheTTL)
        self.logger = logger ?? Networking.defaultLogger
        self.logFileURL = ProcessInfo.processInfo.environment["NETWORKING_LOG_FILE"].flatMap(Networking.resolveLogFileURL)
        // Sweep aged-out files off the request path so the disk cache can't grow without bound (one shard
        // per launch — see `sweepExpiredCacheFiles`).
        Task.detached(priority: .utility) { Networking.sweepExpiredCacheFiles(ttl: cacheTTL) }
    }

    /// A path (containing `/`) is used as given; a bare filename resolves under the app's Caches
    /// directory — sandbox-safe in an app, still readable from a CLI/simulator run.
    static func resolveLogFileURL(_ value: String) -> URL? {
        guard !value.isEmpty else { return nil }
        if value.contains("/") {
            return URL(fileURLWithPath: value)
        }
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return caches.appendingPathComponent(value)
    }

    /// Sets the `Authorization` header to HTTP Basic credentials (`Basic <base64(username:password)>`).
    public func setAuthorizationHeader(username: String, password: String) {
        let credentialsString = "\(username):\(password)"
        if let credentialsData = credentialsString.data(using: .utf8) {
            let base64Credentials = credentialsData.base64EncodedString(options: [])
            let authString = "Basic \(base64Credentials)"

            authorizationHeaderKey = "Authorization"
            authorizationHeaderValue = authString
        }
    }

    /// Sets the `Authorization` header to `Bearer <token>`.
    public func setAuthorizationHeader(token: String) {
        self.token = token
    }

    /// Header fields added to every request.
    public var headerFields: [String: String]?

    public func setHeaderFields(_ headerFields: [String: String]?) {
        self.headerFields = headerFields
    }

    /// Authenticates using a custom header, defaulting to `Authorization`.
    public func setAuthorizationHeader(headerKey: String = "Authorization", headerValue: String) {
        authorizationHeaderKey = headerKey
        authorizationHeaderValue = headerValue
    }

    /// Interceptors wrapping every verb request, applied outermost first.
    public var interceptors: [HTTPInterceptor] = []

    public func setInterceptors(_ interceptors: [HTTPInterceptor]) {
        self.interceptors = interceptors
    }

    nonisolated public func composedURL(with path: String) throws -> URL {
        let encodedPath = path.encodeUTF8() ?? path
        guard let url = URL(string: baseURL + encodedPath) else {
            throw NSError(domain: Networking.domain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Couldn't create a url using baseURL: \(baseURL) and encodedPath: \(encodedPath)"])
        }
        return url
    }

    /// The on-disk URL where a downloaded resource is stored. `cacheName`, when given, is used as the
    /// storage key instead of `path`.
    nonisolated public func destinationURL(for path: String, cacheName: String? = nil) throws -> URL {
        let normalizedCacheName = cacheName?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        var resourcesPath: String
        if let normalizedCacheName = normalizedCacheName {
            resourcesPath = normalizedCacheName
        } else {
            let url = try composedURL(with: path)
            resourcesPath = url.absoluteString
        }

        let component = Networking.filesystemSafeComponent(resourcesPath.replacingOccurrences(of: "/", with: "-"))
        // Shard the cache directory by a hash of the key so the per-launch sweep is O(N / shardCount), not
        // O(N). Always sharded — one uniform layout, no migration or size threshold (see `sweepExpiredCacheFiles`).
        let folderPath = "\(Networking.domain)/\(Networking.shardName(for: component))"
        let finalPath = "\(folderPath)/\(component)"

        guard let url = URL(string: finalPath),
              let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw NSError(domain: Networking.domain, code: 9999, userInfo: [NSLocalizedDescriptionKey: "Couldn't build a cache URL for: \(finalPath)"])
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

    public static func splitBaseURLAndRelativePath(for path: String) -> (baseURL: String, relativePath: String)? {
        guard let encodedPath = path.encodeUTF8(),
              let url = URL(string: encodedPath),
              let baseURLWithDash = URL(string: "/", relativeTo: url)?.absoluteURL.absoluteString else {
            return nil
        }
        let index = baseURLWithDash.index(before: baseURLWithDash.endIndex)
        let baseURL = String(baseURLWithDash[..<index])
        let relativePath = path.replacingOccurrences(of: baseURL, with: "")

        return (baseURL, relativePath)
    }

    /// Empties **both** the in-memory `NSCache` and the on-disk files (clearing only one tier would
    /// leave the other serving deleted data).
    public func clearCache() throws {
        cache.removeAllObjects()
        try Networking.deleteCacheFolder()
    }

    /// Clears the cache (both tiers) plus stored credentials, header fields, and registered fakes.
    public func reset() throws {
        try clearCache()
        fakeRequests.removeAll()
        token = nil
        headerFields = nil
        authorizationHeaderKey = "Authorization"
        authorizationHeaderValue = nil
    }

    // Serializes whole-folder mutations of the shared cache directory so the background sweep (which
    // creates the folder + writes its cursor) can't race `clearCache`/`reset` removing it.
    static let cacheMutationLock = NSLock()

    // Removes the on-disk cache folder (scoped to the networking domain; unrelated files in Caches are
    // untouched). Shared across instances, so it clears the disk cache for all of them.
    static func deleteCacheFolder() throws {
        cacheMutationLock.lock()
        defer { cacheMutationLock.unlock() }
        guard let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let folderURL = cachesURL.appendingPathComponent(URL(string: Networking.domain)!.absoluteString)
        if FileManager.default.exists(at: folderURL) {
            _ = try FileManager.default.remove(at: folderURL)
        }
    }

    static let sweepCursorFileName = ".sweep-shard"

    // Deletes expired files from **one** shard per call (rotated via a tiny cursor file), so each launch's
    // sweep is O(N / shardCount) and everything gets visited over `shardCount` launches. Age is judged by
    // the file's modification date. Best-effort and off the request path.
    static func sweepExpiredCacheFiles(ttl: Duration) {
        cacheMutationLock.lock()
        defer { cacheMutationLock.unlock() }
        guard let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let domainURL = cachesURL.appendingPathComponent(URL(string: Networking.domain)!.absoluteString)
        let now = Date()
        let maxAge = CacheExpiry.seconds(ttl)

        let cursorURL = domainURL.appendingPathComponent(sweepCursorFileName)
        let cursor = (try? String(contentsOf: cursorURL, encoding: .utf8)).flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 0
        let shardURL = domainURL.appendingPathComponent(String(cursor % shardCount, radix: 16))

        if let files = try? FileManager.default.contentsOfDirectory(at: shardURL, includingPropertiesForKeys: [.contentModificationDateKey], options: []) {
            for file in files {
                guard let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else { continue }
                if now.timeIntervalSince(modified) > maxAge {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }

        // Pre-sharding versions wrote files directly under the domain root; clear those strays (the cursor
        // file and the shard subdirectories stay).
        if let rootEntries = try? FileManager.default.contentsOfDirectory(at: domainURL, includingPropertiesForKeys: [.isRegularFileKey], options: []) {
            for entry in rootEntries where entry.lastPathComponent != sweepCursorFileName {
                if (try? entry.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                    try? FileManager.default.removeItem(at: entry)
                }
            }
        }

        try? FileManager.default.createDirectory(at: domainURL, withIntermediateDirectories: true)
        try? String(cursor &+ 1).write(to: cursorURL, atomically: true, encoding: .utf8)
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
}

public extension Networking {
    func cancelAllRequests() async {
        let (dataTasks, uploadTasks, downloadTasks) = await session.tasks
        for sessionTask in dataTasks {
            sessionTask.cancel()
        }
        for sessionTask in downloadTasks {
            sessionTask.cancel()
        }
        for sessionTask in uploadTasks {
            sessionTask.cancel()
        }
    }
}
