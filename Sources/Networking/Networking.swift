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

    /// How long an unused on-disk cache entry survives. Each read or write re-warms the entry (resets its
    /// clock), so something in active use never expires; only entries idle past `cacheTTL` are swept.
    /// Default 7 days. Memory (`NSCache`) is unaffected — it's the warm tier, evicted under memory pressure.
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
        // Bulk-sweep files older than the TTL off the request path, so the disk cache can't grow without
        // bound. This judges by file age (access recency lives in an in-memory log that isn't persisted —
        // see `objectFromCache`), so warmth is a within-session refinement on top of this age bound.
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

        let normalizedResourcesPath = Networking.filesystemSafeComponent(resourcesPath.replacingOccurrences(of: "/", with: "-"))
        let folderPath = Networking.domain
        let finalPath = "\(folderPath)/\(normalizedResourcesPath)"

        if let url = URL(string: finalPath) {
            let directory = FileManager.SearchPathDirectory.cachesDirectory
            if let cachesURL = FileManager.default.urls(for: directory, in: .userDomainMask).first {
                let folderURL = cachesURL.appendingPathComponent(URL(string: folderPath)!.absoluteString)

                if FileManager.default.exists(at: folderURL) == false {
                    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false, attributes: nil)
                }

                let destinationURL = cachesURL.appendingPathComponent(url.absoluteString)

                return destinationURL
            } else {
                throw NSError(domain: Networking.domain, code: 9999, userInfo: [NSLocalizedDescriptionKey: "Couldn't normalize url"])
            }
        } else {
            throw NSError(domain: Networking.domain, code: 9999, userInfo: [NSLocalizedDescriptionKey: "Couldn't create a url using replacedPath: \(finalPath)"])
        }
    }

    public static func splitBaseURLAndRelativePath(for path: String) -> (baseURL: String, relativePath: String) {
        guard let encodedPath = path.encodeUTF8() else { fatalError("Couldn't encode path to UTF8: \(path)") }
        guard let url = URL(string: encodedPath) else { fatalError("Path \(encodedPath) can't be converted to url") }
        guard let baseURLWithDash = URL(string: "/", relativeTo: url)?.absoluteURL.absoluteString else { fatalError("Can't find absolute url of url: \(url)") }
        let index = baseURLWithDash.index(before: baseURLWithDash.endIndex)
        let baseURL = String(baseURLWithDash[..<index])
        let relativePath = path.replacingOccurrences(of: baseURL, with: "")

        return (baseURL, relativePath)
    }

    /// Empties the cache — both the in-memory `NSCache` and the on-disk files. (The static
    /// disk-only path is gone; clearing must address both tiers or memory keeps serving deleted data.)
    public func clearCache() throws {
        cache.removeAllObjects()
        cacheExpiry.forgetAll()
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

    // Removes the on-disk cache folder (scoped to the networking domain; unrelated files in Caches are
    // untouched). Shared across instances, so it clears the disk cache for all of them.
    static func deleteCacheFolder() throws {
        guard let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let folderURL = cachesURL.appendingPathComponent(URL(string: Networking.domain)!.absoluteString)
        if FileManager.default.exists(at: folderURL) {
            _ = try FileManager.default.remove(at: folderURL)
        }
    }

    // Deletes cache files whose age exceeds `ttl` (judged by file date — the in-memory access log isn't
    // persisted across launches). Best-effort and off the request path.
    static func sweepExpiredCacheFiles(ttl: Duration) {
        guard let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let folderURL = cachesURL.appendingPathComponent(URL(string: Networking.domain)!.absoluteString)
        guard let files = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.contentModificationDateKey], options: []) else { return }
        let maxAge = CacheExpiry.seconds(ttl)
        let now = Date()
        for file in files {
            guard let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else { continue }
            if now.timeIntervalSince(modified) > maxAge {
                try? FileManager.default.removeItem(at: file)
            }
        }
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
