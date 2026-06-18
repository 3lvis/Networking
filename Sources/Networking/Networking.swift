import Foundation
import os.log

public extension Networking.StatusCodeType {
    /// Classifies an HTTP status code (with `URLError.cancelled` mapped to `.cancelled`).
    init(statusCode: Int) {
        switch statusCode {
        case URLError.cancelled.rawValue:
            self = .cancelled
        case 100 ..< 200:
            self = .informational
        case 200 ..< 300:
            self = .successful
        case 300 ..< 400:
            self = .redirection
        case 400 ..< 500:
            self = .clientError
        case 500 ..< 600:
            self = .serverError
        default:
            self = .unknown
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
    // Shared by reference with `cacheStore` — kept here so the disk-cache subsystem lives in `CacheStore`
    // while the injected/inspectable `NSCache` stays reachable on the actor.
    nonisolated(unsafe) let cache: NSCache<AnyObject, AnyObject>
    let cacheStore: CacheStore

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
    nonisolated public var cacheTTL: Duration { cacheStore.ttl }

    public func setCacheTTL(_ ttl: Duration) {
        cacheStore.setTTL(ttl)
    }

    public init(baseURL: String = "", configuration: URLSessionConfiguration = .default, cache: NSCache<AnyObject, AnyObject>? = nil, logger: Logger? = nil, cacheTTL: Duration = .seconds(7 * 24 * 60 * 60)) {
        self.baseURL = baseURL
        self.configuration = configuration
        let memoryCache = cache ?? NSCache()
        self.cache = memoryCache
        self.cacheStore = CacheStore(memory: memoryCache, ttl: cacheTTL, folderName: Networking.domain)
        self.logger = logger ?? Networking.defaultLogger
        self.logFileURL = ProcessInfo.processInfo.environment["NETWORKING_LOG_FILE"].flatMap(Networking.resolveLogFileURL)
        // Sweep aged-out files off the request path so the disk cache can't grow without bound (one shard
        // per launch — see `CacheStore.sweepExpired`).
        let store = self.cacheStore
        Task.detached(priority: .utility) { store.sweepExpired() }
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
            throw NetworkingError.invalidRequest(.invalidURL(path))
        }
        return url
    }

    /// The on-disk URL where a downloaded resource is stored. `cacheName`, when given, is used as the
    /// storage key instead of `path`.
    nonisolated public func destinationURL(for path: String, cacheName: String? = nil) throws -> URL {
        try cacheStore.destinationURL(forResource: cacheResource(for: path, cacheName: cacheName))
    }

    // The cache key: a percent-encoded `cacheName` verbatim, else the request's full effective URL.
    nonisolated func cacheResource(for path: String, cacheName: String?) throws -> String {
        if let normalizedCacheName = cacheName?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return normalizedCacheName
        }
        return try composedURL(with: path).absoluteString
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
        try cacheStore.clear()
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
