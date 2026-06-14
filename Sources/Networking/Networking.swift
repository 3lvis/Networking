import Foundation
import os.log

public extension Int {

    /// Categorizes a status code.
    ///
    /// - Returns: The NetworkingStatusCodeType of the status code.
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

// An actor: its mutable state (`fakeRequests`, auth/header config, `unauthorizedRequestCallback`)
// is isolated, so the compiler guarantees no data races when an instance is shared across tasks.
// Trade-off vs the old `open class`: no subclassing, and isolated members are accessed with `await`.
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

    /// Categorizes a status code.
    ///
    /// - informational: This class of status code indicates a provisional response, consisting only of the Status-Line and optional headers, and is terminated by an empty line.
    /// - successful: This class of status code indicates that the client's request was successfully received, understood, and accepted.
    /// - redirection: This class of status code indicates that further action needs to be taken by the user agent in order to fulfill the request.
    /// - clientError: The 4xx class of status code is intended for cases in which the client seems to have erred.
    /// - serverError: Response status codes beginning with the digit "5" indicate cases in which the server is aware that it has erred or is incapable of performing the request.
    /// - cancelled: When a request gets cancelled
    /// - unknown: This response status code could be used by Foundation for other types of states.
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

    /// Observability hook — receives a `.started` and a `.completed` event per request. Replaces the
    /// old console logging. The library itself only logs to `os.Logger` (filterable unified logging).
    public typealias Observer = @Sendable (NetworkingEvent) -> Void
    var observer: Observer?

    /// Sets the observability hook (actor-isolated setter).
    public func setObserver(_ observer: Observer?) {
        self.observer = observer
    }

    // Live `events()` consumers. Each call to `events()` registers a continuation here; `emit` fans out
    // to all of them, and `onTermination` drops one when its consumer's task ends.
    private var streamContinuations: [UUID: AsyncStream<NetworkingEvent>.Continuation] = [:]

    /// A stream of observability events — the structured-concurrency counterpart to `setObserver`.
    /// Iterate it with `for await event in await networking.events()` to accumulate/transform events
    /// without the `@Sendable`-closure capture dance. Each call returns its own multicast stream; the
    /// closure observer still fires too. Buffer keeps the newest 256 events for a slow consumer.
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

    /// The single fan-out point for observability events: the closure observer and every live `events()` stream.
    func emit(_ event: NetworkingEvent) {
        observer?(event)
        for continuation in streamContinuations.values {
            continuation.yield(event)
        }
    }

    /// Whether the library emits its own diagnostics — request starts and failures. On by default:
    /// this is the out-of-the-box logging, sent to `os.Logger` (Xcode console / Console.app) and, when
    /// a log file is configured, mirrored there. Turn it off for release builds; `setObserver` still fires.
    public var isLoggingEnabled = true

    /// Enables or disables the built-in diagnostics (actor-isolated setter).
    public func setLoggingEnabled(_ enabled: Bool) {
        self.isLoggingEnabled = enabled
    }

    /// When set, the built-in diagnostics are *also* appended to this file as plain text — so a CLI or
    /// headless/agent run (where `os.Logger` isn't visible in stdout) can read what happened. Defaults
    /// from the `NETWORKING_LOG_FILE` environment variable, so logs can be captured with no code change.
    public var logFileURL: URL?

    /// Sets (or clears) the diagnostics log file (actor-isolated setter).
    public func setLogFileURL(_ url: URL?) {
        self.logFileURL = url
    }

    /// Emits one built-in diagnostic line to `os.Logger` and, if configured, to the log file.
    func record(_ message: String, level: OSLogType) {
        guard isLoggingEnabled else { return }
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

    /// Header field names whose values are replaced with `<redacted>` in emitted `RequestContext.headers`.
    /// Matched case-insensitively; the active authorization header key is always redacted too.
    var redactedHeaderFields: Set<String> = ["Authorization", "Cookie", "Set-Cookie"]

    /// Replaces the set of redacted header names (actor-isolated setter).
    public func setRedactedHeaderFields(_ fields: Set<String>) {
        self.redactedHeaderFields = fields
    }

    /// Redacts sensitive header values for inclusion in an emitted event.
    func redactedHeaders(_ headers: [String: String]) -> [String: String] {
        let redacted = Set(redactedHeaderFields.union([authorizationHeaderKey]).map { $0.lowercased() })
        return headers.reduce(into: [String: String]()) { result, pair in
            result[pair.key] = redacted.contains(pair.key.lowercased()) ? "<redacted>" : pair.value
        }
    }

    /// The boundary used for multipart requests.
    nonisolated let boundary = String(format: "com.elvisnunez.networking.%08x%08x", arc4random(), arc4random())

    lazy var session: URLSession = {
        URLSession(configuration: self.configuration)
    }()

    /// Caching options
    public enum CachingLevel {
        case memory
        case memoryAndFile
        case none
    }

    private static let defaultLogger = Logger(subsystem: "com.elvisnunez.networking", category: "network")

    let logger: Logger
    /// Base initializer, it creates an instance of `Networking`.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for HTTP requests under `Networking`.
    ///   - configuration: The URLSessionConfiguration configuration to be used
    ///   - cache: The NSCache to use, it has a built-in default one.
    public init(baseURL: String = "", configuration: URLSessionConfiguration = .default, cache: NSCache<AnyObject, AnyObject>? = nil, logger: Logger? = nil) {
        self.baseURL = baseURL
        self.configuration = configuration
        self.cache = cache ?? NSCache()
        self.logger = logger ?? Networking.defaultLogger
        self.logFileURL = ProcessInfo.processInfo.environment["NETWORKING_LOG_FILE"].flatMap(Networking.resolveLogFileURL)
    }

    /// Resolves the `NETWORKING_LOG_FILE` value to a URL. An absolute/relative path is used as given; a
    /// bare filename resolves under the app's Caches directory — sandbox-safe in an app (the default
    /// location CocoaLumberjack uses too) and still readable from a CLI/simulator run.
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

    /// Authenticates using Basic Authentication, it converts username:password to Base64 then sets the Authorization header to "Basic \(Base64(username:password))".
    ///
    /// - Parameters:
    ///   - username: The username to be used.
    ///   - password: The password to be used.
    public func setAuthorizationHeader(username: String, password: String) {
        let credentialsString = "\(username):\(password)"
        if let credentialsData = credentialsString.data(using: .utf8) {
            let base64Credentials = credentialsData.base64EncodedString(options: [])
            let authString = "Basic \(base64Credentials)"

            authorizationHeaderKey = "Authorization"
            authorizationHeaderValue = authString
        }
    }

    /// Authenticates using a Bearer token, sets the Authorization header to "Bearer \(token)".
    ///
    /// - Parameter token: The token to be used.
    public func setAuthorizationHeader(token: String) {
        self.token = token
    }

    /// Sets the header fields for every HTTP call.
    public var headerFields: [String: String]?

    /// Sets the header fields for every HTTP call (actor-isolated setter).
    public func setHeaderFields(_ headerFields: [String: String]?) {
        self.headerFields = headerFields
    }

    /// Authenticates using a custom HTTP Authorization header.
    ///
    /// - Parameters:
    ///   - headerKey: Sets this value as the key for the HTTP `Authorization` header
    ///   - headerValue: Sets this value to the HTTP `Authorization` header or to the `headerKey` if you provided that.
    public func setAuthorizationHeader(headerKey: String = "Authorization", headerValue: String) {
        authorizationHeaderKey = headerKey
        authorizationHeaderValue = headerValue
    }

    /// Callback used to intercept requests that return with a 403 or 401 status code.
    public var unauthorizedRequestCallback: (@Sendable () -> Void)?

    /// Sets the unauthorized-request callback (actor-isolated setter).
    public func setUnauthorizedRequestCallback(_ callback: (@Sendable () -> Void)?) {
        self.unauthorizedRequestCallback = callback
    }

    /// Returns a URL by appending the provided path to the Networking's base URL.
    ///
    /// - Parameter path: The path to be appended to the base URL.
    /// - Returns: A URL generated after appending the path to the base URL.
    /// - Throws: An error if the URL couldn't be created.
    nonisolated public func composedURL(with path: String) throws -> URL {
        let encodedPath = path.encodeUTF8() ?? path
        guard let url = URL(string: baseURL + encodedPath) else {
            throw NSError(domain: Networking.domain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Couldn't create a url using baseURL: \(baseURL) and encodedPath: \(encodedPath)"])
        }
        return url
    }

    /// Returns the URL used to store a resource for a certain path. Useful to find where a download image is located.
    ///
    /// - Parameters:
    ///   - path: The path used to download the resource.
    ///   - cacheName: The alias to be used for storing the resource, if a cache name is provided, this will be used instead of the path.
    /// - Returns: A URL where a resource has been stored.
    /// - Throws: An error if the URL couldn't be created.
    nonisolated public func destinationURL(for path: String, cacheName: String? = nil) throws -> URL {
        let normalizedCacheName = cacheName?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        var resourcesPath: String
        if let normalizedCacheName = normalizedCacheName {
            resourcesPath = normalizedCacheName
        } else {
            let url = try composedURL(with: path)
            resourcesPath = url.absoluteString
        }

        let normalizedResourcesPath = resourcesPath.replacingOccurrences(of: "/", with: "-")
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

    /// Splits a url in base url and relative path.
    ///
    /// - Parameter path: The full url to be splitted.
    /// - Returns: A base url and a relative path.
    public static func splitBaseURLAndRelativePath(for path: String) -> (baseURL: String, relativePath: String) {
        guard let encodedPath = path.encodeUTF8() else { fatalError("Couldn't encode path to UTF8: \(path)") }
        guard let url = URL(string: encodedPath) else { fatalError("Path \(encodedPath) can't be converted to url") }
        guard let baseURLWithDash = URL(string: "/", relativeTo: url)?.absoluteURL.absoluteString else { fatalError("Can't find absolute url of url: \(url)") }
        let index = baseURLWithDash.index(before: baseURLWithDash.endIndex)
        let baseURL = String(baseURLWithDash[..<index])
        let relativePath = path.replacingOccurrences(of: baseURL, with: "")

        return (baseURL, relativePath)
    }

    /// Removes the stored credentials and cached data.
    public func reset() throws {
        cache.removeAllObjects()
        fakeRequests.removeAll()
        token = nil
        headerFields = nil
        authorizationHeaderKey = "Authorization"
        authorizationHeaderValue = nil

        try Networking.deleteCachedFiles()
    }

    /// Deletes the downloaded/cached files.
    public static func deleteCachedFiles() throws {
        let directory = FileManager.SearchPathDirectory.cachesDirectory
        if let cachesURL = FileManager.default.urls(for: directory, in: .userDomainMask).first {
            let folderURL = cachesURL.appendingPathComponent(URL(string: Networking.domain)!.absoluteString)
            if FileManager.default.exists(at: folderURL) {
                _ = try FileManager.default.remove(at: folderURL)
            }
        }
    }
}

public extension Networking {
    /// Cancels all the current requests.
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
