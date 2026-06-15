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
