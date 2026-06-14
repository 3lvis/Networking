import Foundation

/// Identifying context for a single request, shared by its `.started` and `.completed` events so a
/// consumer can correlate the two by `id`.
public struct RequestContext: Sendable {
    /// A unique id for this request, also stamped into the library's `os.Logger` lines.
    public let id: UUID
    public let method: String
    public let url: URL?
    /// Request headers with sensitive values replaced by `<redacted>` (see `setRedactedHeaderFields`).
    public let headers: [String: String]
}

/// How a request finished.
public enum Outcome: Sendable {
    case success(statusCode: Int, byteCount: Int)
    case failure(NetworkingError)
}

/// A `Sendable` distillation of `URLSessionTaskMetrics` — the per-request timing breakdown. Each
/// interval is `nil` when the phase didn't happen (e.g. a reused connection has no DNS/TLS phase).
public struct TransactionMetrics: Sendable {
    public let domainLookup: TimeInterval?      // DNS
    public let connect: TimeInterval?           // TCP (+ TLS) connect
    public let secureConnection: TimeInterval?  // TLS handshake
    public let request: TimeInterval?           // sending the request
    public let response: TimeInterval?          // receiving the response
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

/// A structured observability event. Set a handler with `setObserver` to receive one `.started` and
/// one `.completed` per request — for logging, analytics, a network-activity indicator, etc. This
/// replaces console printing; the library itself only logs to `os.Logger` (filterable unified logging).
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
