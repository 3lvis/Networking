import Foundation

/// The raw result of one network attempt, as seen by interceptors — below the generic `Result<T>` decode
/// layer, so the same interceptor serves every response type.
public struct HTTPExchange: Sendable {
    public let data: Data
    public let response: HTTPURLResponse

    public init(data: Data, response: HTTPURLResponse) {
        self.data = data
        self.response = response
    }
}

/// A composable hook wrapping every verb request. Inspect or mutate the outgoing `URLRequest`, call
/// `next` to run the rest of the chain (the innermost being the real network call), then inspect or
/// transform the result. Calling `next` again replays the request — the basis for retry and auth-refresh.
/// Registered outermost-first via `setInterceptors(_:)`.
public protocol HTTPInterceptor: Sendable {
    func intercept(
        _ request: URLRequest,
        next: @Sendable (URLRequest) async throws -> HTTPExchange
    ) async throws -> HTTPExchange
}

/// On an unauthorized response, refresh the credential and replay the request once with it. This is what
/// the old `unauthorizedRequestCallback` wanted to be — a fire-and-forget callback could notify but never
/// retry. Pure "tell me on 401" needs no interceptor; it's already a `.completed(_, .failure)` on `events()`.
public struct AuthRefreshInterceptor: HTTPInterceptor {
    /// Status codes that trigger a refresh + replay. Defaults to 401 and 403.
    public let triggeringStatusCodes: Set<Int>
    /// The header the refreshed credential is written to on the replayed request.
    public let headerField: String
    private let coordinator: RefreshCoordinator

    /// - Parameter refresh: produces a fresh credential value (e.g. `"Bearer …"`). Returning `nil` gives up —
    ///   the original unauthorized response is returned unchanged rather than replayed.
    public init(
        triggeringStatusCodes: Set<Int> = [401, 403],
        headerField: String = "Authorization",
        refresh: @escaping @Sendable () async throws -> String?
    ) {
        self.triggeringStatusCodes = triggeringStatusCodes
        self.headerField = headerField
        self.coordinator = RefreshCoordinator(refresh)
    }

    public func intercept(
        _ request: URLRequest,
        next: @Sendable (URLRequest) async throws -> HTTPExchange
    ) async throws -> HTTPExchange {
        let exchange = try await next(request)
        guard triggeringStatusCodes.contains(exchange.response.statusCode) else { return exchange }
        guard let refreshedValue = try await coordinator.refreshOnce() else { return exchange }
        var retried = request
        retried.setValue(refreshedValue, forHTTPHeaderField: headerField)
        return try await next(retried)
    }
}

/// Retries a request when it fails transiently — a dropped connection/timeout, or an HTTP status in
/// `retryableStatusCodes` (408/429/5xx by default). Backs off exponentially with full jitter between
/// attempts, capped at `maxDelay`, and honors a `Retry-After` response header when the server sends one.
public struct RetryInterceptor: HTTPInterceptor {
    /// Total attempts including the first try (so `3` means the original plus up to two retries).
    public let maxAttempts: Int
    /// First-retry delay; each subsequent retry doubles it (before jitter), capped at `maxDelay`.
    public let baseDelay: Duration
    /// Upper bound on any single backoff wait.
    public let maxDelay: Duration
    /// HTTP statuses worth retrying. Defaults to `NetworkingError.retryableStatusCodes`.
    public let retryableStatusCodes: Set<Int>

    public init(
        maxAttempts: Int = 3,
        baseDelay: Duration = .milliseconds(500),
        maxDelay: Duration = .seconds(30),
        retryableStatusCodes: Set<Int> = NetworkingError.retryableStatusCodes
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.retryableStatusCodes = retryableStatusCodes
    }

    public func intercept(
        _ request: URLRequest,
        next: @Sendable (URLRequest) async throws -> HTTPExchange
    ) async throws -> HTTPExchange {
        var attempt = 1
        while true {
            do {
                let exchange = try await next(request)
                let shouldRetry = retryableStatusCodes.contains(exchange.response.statusCode)
                guard shouldRetry, attempt < maxAttempts else { return exchange }
                // A server-sent Retry-After wins over our backoff (still capped at maxDelay).
                let delay = Self.retryAfterDelay(from: exchange.response).map { Swift.min($0, maxDelay) }
                    ?? backoffDelay(forAttempt: attempt)
                try await Task.sleep(for: delay)
                attempt += 1
            } catch let error as URLError where attempt < maxAttempts && NetworkingError.isRetryableTransport(error) {
                try await Task.sleep(for: backoffDelay(forAttempt: attempt))
                attempt += 1
            }
        }
    }

    private func backoffDelay(forAttempt attempt: Int) -> Duration {
        let exponential = baseDelay.seconds * pow(2.0, Double(attempt - 1))
        let capped = Swift.min(exponential, maxDelay.seconds)
        // Full jitter (random in [0, capped]) spreads retries so a fleet doesn't stampede a recovering server.
        return .seconds(Double.random(in: 0...capped))
    }

    // Retry-After is either a count of seconds or an HTTP-date (RFC 9110); returns nil when absent/unparseable.
    static func retryAfterDelay(from response: HTTPURLResponse) -> Duration? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespaces),
              !value.isEmpty else { return nil }
        if let seconds = Int(value) {
            return .seconds(max(0, seconds))
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: value) else { return nil }
        return .seconds(max(0, date.timeIntervalSinceNow))
    }
}

private extension Duration {
    var seconds: Double {
        let (wholeSeconds, attoseconds) = components
        return Double(wholeSeconds) + Double(attoseconds) / 1e18
    }
}

/// Dedupes concurrent refreshes: while one is in flight, later callers await its result instead of each
/// starting their own. Without this, every request that hits an expired credential at the same time fires
/// its own refresh (the OkHttp token-refresh stampede).
actor RefreshCoordinator {
    private let refresh: @Sendable () async throws -> String?
    private var inFlight: Task<String?, Error>?

    init(_ refresh: @escaping @Sendable () async throws -> String?) {
        self.refresh = refresh
    }

    func refreshOnce() async throws -> String? {
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task { try await refresh() }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}
