import Foundation

public extension Networking {
    /// Scope of the built-in diagnostics. Logged requests always get *full* detail; the level only
    /// chooses *which* requests: `.none` (nothing), `.failures` (the default), or `.all`.
    enum LogLevel: Sendable {
        case none
        case failures
        case all
    }
}

/// Identifying context for a single request, shared by its `.started` and `.completed` events so a
/// consumer can correlate the two by `id`.
public struct RequestContext: Sendable {
    /// A unique id for this request, also stamped into the library's `os.Logger` lines.
    public let id: UUID
    public let method: String
    public let url: URL?
    /// The real request headers, unredacted — redaction applies only to the built-in logs, not here.
    public let headers: [String: String]
}

extension RequestContext {
    // Owns the two normalizations every call site repeated: the HTTP method string and a nil header
    // set. The URL stays a caller concern — it's resolved differently per site (best-effort
    // `composedURL` from a path, a built request's URL, or nil on a pre-flight failure).
    init(id: UUID, requestType: Networking.RequestType, url: URL?, headers: [String: String]?) {
        self.init(id: id, method: requestType.rawValue, url: url, headers: headers ?? [:])
    }
}

public enum Outcome: Sendable {
    case success(statusCode: Int, byteCount: Int)
    case failure(NetworkingError)
}

/// A `Sendable` distillation of `URLSessionTaskMetrics` — the per-request timing breakdown. Each
/// interval is `nil` when the phase didn't happen (e.g. a reused connection has no DNS/TLS phase).
public struct TransactionMetrics: Sendable {
    public let domainLookup: TimeInterval?
    public let connect: TimeInterval?
    public let secureConnection: TimeInterval?
    public let request: TimeInterval?
    public let response: TimeInterval?
    public let countOfRequestBodyBytesSent: Int64
    public let countOfResponseBodyBytesReceived: Int64
    public let redirectCount: Int
    public let isFromCache: Bool

    init?(_ metrics: URLSessionTaskMetrics) {
        guard let transaction = metrics.transactionMetrics.last else { return nil }
        func interval(_ start: Date?, _ end: Date?) -> TimeInterval? {
            guard let start, let end else { return nil }
            return end.timeIntervalSince(start)
        }
        domainLookup = interval(transaction.domainLookupStartDate, transaction.domainLookupEndDate)
        connect = interval(transaction.connectStartDate, transaction.connectEndDate)
        secureConnection = interval(transaction.secureConnectionStartDate, transaction.secureConnectionEndDate)
        request = interval(transaction.requestStartDate, transaction.requestEndDate)
        response = interval(transaction.responseStartDate, transaction.responseEndDate)
        countOfRequestBodyBytesSent = transaction.countOfRequestBodyBytesSent
        countOfResponseBodyBytesReceived = transaction.countOfResponseBodyBytesReceived
        redirectCount = metrics.redirectCount
        isFromCache = transaction.resourceFetchType == .localCache
    }
}

/// A structured observability event. Iterate `events()` to receive one `.started` and one `.completed`
/// per request — for logging, analytics, a network-activity indicator, etc.
public enum NetworkingEvent: Sendable {
    /// Emitted just before a request is sent.
    case started(RequestContext)
    /// Emitted once a request finishes. `duration` is the wall-clock time measured by the library;
    /// `metrics` is the richer `URLSessionTaskMetrics` breakdown, present only for real network requests.
    case completed(RequestContext, outcome: Outcome, duration: Duration, metrics: TransactionMetrics?)
}

/// Collects `URLSessionTaskMetrics` for a single task via the per-task delegate. Genuinely synchronized
/// (the delegate callback runs off the delegate queue, the read happens after the awaited request
/// resumes), so `@unchecked Sendable` is sound here rather than an unverified promise.
final class MetricsCollector: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var collected: URLSessionTaskMetrics?

    var metrics: URLSessionTaskMetrics? {
        lock.lock(); defer { lock.unlock() }
        return collected
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        lock.lock(); defer { lock.unlock() }
        collected = metrics
    }
}
