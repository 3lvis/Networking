import Foundation

/// Turns a non-2xx Rails error body into a human-readable `serverMessage`, throwing `.http`. Opt-in: a
/// general client shouldn't assume a Rails backend, so the full-shape knowledge lives here rather than in
/// the core error model. Recognizes the shapes a Rails API actually emits:
/// - top-level `{ "error": "…" }` or `{ "message": "…" }`
/// - ActiveModel `{ "errors": { "field": ["…"], "base": ["…"] } }`, including nested groups
///   (`{ "errors": { "validation": { "start_time": ["…"] } } }`)
/// - JSON:API `{ "errors": [ { "detail": "…", "title": "…" } ] }`
///
/// A body it doesn't recognize is passed through untouched, so the core builds the standard `.http` error.
/// Register it **outermost** (before `RetryInterceptor`) so it shapes the final response after retries
/// have run. Message order across multiple ActiveModel fields isn't deterministic — JSON object key order
/// isn't preserved — though a JSON:API `errors` array keeps its order.
public struct RailsErrorInterceptor: HTTPInterceptor {
    public init() {}

    public func intercept(
        _ request: URLRequest,
        next: @Sendable (URLRequest) async throws -> HTTPExchange
    ) async throws -> HTTPExchange {
        let exchange = try await next(request)
        guard !(200..<300).contains(exchange.response.statusCode) else { return exchange }
        let messages = RailsErrorBody.messages(from: exchange.data)
        guard !messages.isEmpty else { return exchange }
        throw NetworkingError.http(HTTPError(
            statusCode: exchange.response.statusCode,
            metadata: ResponseMetadata(response: exchange.response, body: exchange.data),
            serverMessage: messages.joined(separator: "; ")
        ))
    }
}

private enum RailsErrorBody {
    /// Human-readable messages pulled from a Rails-style error body, or `[]` if the body isn't one.
    static func messages(from data: Data) -> [String] {
        guard let root = try? JSONDecoder().decode(JSON.self, from: data),
              case let .object(top) = root else { return [] }

        var messages = [String]()
        if case let .string(error) = top["error"] { messages.append(error) }
        if case let .string(message) = top["message"] { messages.append(message) }

        switch top["errors"] {
        case let .object(map):
            // ActiveModel: every string leaf is a message — flattens `{ field: [msgs] }`, `base`, and
            // grouped `{ group: { field: [msgs] } }` alike.
            messages.append(contentsOf: leafStrings(in: .object(map)))
        case let .array(items):
            // JSON:API: an array of error objects, each carrying `detail` (preferred) or `title`.
            for case let .object(item) in items {
                if case let .string(detail) = item["detail"] {
                    messages.append(detail)
                } else if case let .string(title) = item["title"] {
                    messages.append(title)
                }
            }
        default:
            break
        }

        return messages.filter { !$0.isEmpty }
    }

    private static func leafStrings(in node: JSON) -> [String] {
        switch node {
        case let .string(value): return [value]
        case let .array(items): return items.flatMap(leafStrings)
        case let .object(map): return map.values.flatMap(leafStrings)
        case .other: return []
        }
    }

    /// A typed JSON tree, just enough to walk an error body for its string leaves (no `Any`).
    private indirect enum JSON: Decodable {
        case string(String)
        case array([JSON])
        case object([String: JSON])
        case other

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = .string(string)
            } else if let object = try? container.decode([String: JSON].self) {
                self = .object(object)
            } else if let array = try? container.decode([JSON].self) {
                self = .array(array)
            } else {
                self = .other
            }
        }
    }
}
