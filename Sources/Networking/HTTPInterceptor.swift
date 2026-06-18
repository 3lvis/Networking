import Foundation

/// The raw result of one network attempt — below the `Result<T>` decode layer, so one interceptor serves
/// every response type.
public struct HTTPExchange: Sendable {
    public let data: Data
    public let response: HTTPURLResponse

    public init(data: Data, response: HTTPURLResponse) {
        self.data = data
        self.response = response
    }
}

/// A composable hook wrapping every verb request. `next` runs the rest of the chain (innermost is the real
/// network call); calling it again replays the request — the basis for retry and auth-refresh.
public protocol HTTPInterceptor: Sendable {
    func intercept(
        _ request: URLRequest,
        next: @Sendable (URLRequest) async throws -> HTTPExchange
    ) async throws -> HTTPExchange
}

/// On an unauthorized response, refresh the credential and replay the request once.
public struct AuthRefreshInterceptor: HTTPInterceptor {
    public let triggeringStatusCodes: Set<Int>
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
    public let baseDelay: Duration
    public let maxDelay: Duration
    public let retryableStatusCodes: Set<Int>
    /// HTTP methods safe to retry. Defaults to the idempotent set — retrying `POST`/`PATCH` could duplicate
    /// a side effect (a second charge, a duplicate mutation), since the server may have processed the first
    /// attempt before the timeout/5xx. Opt non-idempotent methods in only when they carry an idempotency key.
    public let retryableMethods: Set<String>

    public init(
        maxAttempts: Int = 3,
        baseDelay: Duration = .milliseconds(500),
        maxDelay: Duration = .seconds(30),
        retryableStatusCodes: Set<Int> = NetworkingError.retryableStatusCodes,
        retryableMethods: Set<String> = ["GET", "HEAD", "PUT", "DELETE", "OPTIONS", "TRACE"]
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.retryableStatusCodes = retryableStatusCodes
        self.retryableMethods = Set(retryableMethods.map { $0.uppercased() })
    }

    public func intercept(
        _ request: URLRequest,
        next: @Sendable (URLRequest) async throws -> HTTPExchange
    ) async throws -> HTTPExchange {
        let methodAllowsRetry = retryableMethods.contains((request.httpMethod ?? "GET").uppercased())
        var attempt = 1
        while true {
            do {
                let exchange = try await next(request)
                let shouldRetry = methodAllowsRetry && retryableStatusCodes.contains(exchange.response.statusCode)
                guard shouldRetry, attempt < maxAttempts else { return exchange }
                let delay = Self.retryAfterDelay(from: exchange.response).map { Swift.min($0, maxDelay) }
                    ?? backoffDelay(forAttempt: attempt)
                try await Task.sleep(for: delay)
                attempt += 1
            } catch let error as URLError where attempt < maxAttempts && methodAllowsRetry && NetworkingError.isRetryableTransport(error) {
                try await Task.sleep(for: backoffDelay(forAttempt: attempt))
                attempt += 1
            }
        }
    }

    private func backoffDelay(forAttempt attempt: Int) -> Duration {
        let exponential = baseDelay.seconds * pow(2.0, Double(attempt - 1))
        let capped = Swift.min(exponential, maxDelay.seconds)
        // Full jitter spreads retries so a fleet doesn't stampede a recovering server.
        return .seconds(Double.random(in: 0...capped))
    }

    // Retry-After is either a count of seconds or an HTTP-date (RFC 9110).
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

/// Validates a successful (2xx) response beyond its status code — content-type, envelope shape — turning a
/// "2xx but wrong" response into a typed `.validation` failure. Non-2xx responses pass through untouched so
/// they still surface as `.http` errors. Register it outermost (before retry) to validate the final result.
public struct ResponseValidatorInterceptor: HTTPInterceptor {
    public enum Validation: Sendable {
        case valid
        case invalid(reason: String)
    }

    private let validate: @Sendable (HTTPExchange) -> Validation

    public init(validate: @escaping @Sendable (HTTPExchange) -> Validation) {
        self.validate = validate
    }

    public func intercept(
        _ request: URLRequest,
        next: @Sendable (URLRequest) async throws -> HTTPExchange
    ) async throws -> HTTPExchange {
        let exchange = try await next(request)
        guard (200..<300).contains(exchange.response.statusCode) else { return exchange }
        switch validate(exchange) {
        case .valid:
            return exchange
        case let .invalid(reason):
            throw NetworkingError.validation(reason: reason, ResponseMetadata(response: exchange.response, body: exchange.data))
        }
    }
}

/// Dedupes concurrent refreshes: while one is in flight, later callers await it rather than each firing
/// their own (the token-refresh stampede).
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
