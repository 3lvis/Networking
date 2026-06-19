import Foundation

/// A request failure, categorized by where it happened so callers can inspect the underlying cause
/// rather than parse a stringified catch-all.
public enum NetworkingError: Error {
    /// The request couldn't be built or its body/parameters couldn't be encoded — a caller-side bug.
    case invalidRequest(InvalidRequestReason)
    /// The request never produced an HTTP response: offline, DNS failure, TLS failure, timeout, etc.
    case transport(URLError)
    /// An HTTP response arrived with a non-2xx status code.
    case http(HTTPError)
    /// A response arrived but its body couldn't be decoded into the requested type.
    case decoding(DecodingError, ResponseMetadata)
    /// A 2xx response failed a registered validator — structurally fine but not acceptable.
    case validation(reason: String, ResponseMetadata)
    /// The response wasn't an HTTP response at all.
    case invalidResponse
    case cancelled
}

extension NetworkingError {
    /// The HTTP status code, when the failure carries one.
    public var statusCode: Int? {
        switch self {
        case .http(let error): return error.statusCode
        case .decoding(_, let metadata): return metadata.statusCode
        case .validation(_, let metadata): return metadata.statusCode
        default: return nil
        }
    }

    public var isCancelled: Bool {
        if case .cancelled = self { return true }
        return false
    }

    /// The response metadata, when the failure carries a response.
    public var responseMetadata: ResponseMetadata? {
        switch self {
        case .http(let error): return error.metadata
        case .decoding(_, let metadata): return metadata
        case .validation(_, let metadata): return metadata
        default: return nil
        }
    }

    /// The default statuses `RetryInterceptor` retries, and the source of truth for `isRetryable`.
    public static let retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504]

    /// Whether a transport failure is transient (a dropped connection or timeout) and so worth retrying.
    public static func isRetryableTransport(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    /// Whether retrying might plausibly succeed. Conservative: only transient transport failures and
    /// `retryableStatusCodes` — never decoding, invalid-request, invalid-response, or cancellation.
    public var isRetryable: Bool {
        switch self {
        case .transport(let error):
            return Self.isRetryableTransport(error)
        case .http(let error):
            return Self.retryableStatusCodes.contains(error.statusCode)
        case .invalidRequest, .decoding, .validation, .invalidResponse, .cancelled:
            return false
        }
    }
}

/// Why a request couldn't be built or encoded. Carries a message rather than the typed encoding error,
/// since these are caller-side setup bugs where the description is what's actionable.
public enum InvalidRequestReason: Sendable, Equatable {
    case invalidURL(String)
    case bodyEncodingFailed(message: String)
    case parameterEncodingFailed(message: String)
}

/// A non-2xx HTTP response, with everything needed to inspect or log it.
public struct HTTPError: Error, Sendable {
    public let statusCode: Int
    public let metadata: ResponseMetadata

    public init(statusCode: Int, metadata: ResponseMetadata) {
        self.statusCode = statusCode
        self.metadata = metadata
    }

    public var isClientError: Bool { (400..<500).contains(statusCode) }
    public var isServerError: Bool { (500..<600).contains(statusCode) }
}

/// Metadata about an HTTP response, retained on failures for inspection, logging, and debugging.
public struct ResponseMetadata: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data

    public init(statusCode: Int, headers: [String: String], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    public init(response: HTTPURLResponse, body: Data) {
        let headers = Dictionary(
            uniqueKeysWithValues: response.allHeaderFields.compactMap { key, value in
                (key as? String).map { ($0, "\(value)") }
            })
        self.init(statusCode: response.statusCode, headers: headers, body: body)
    }

    public func decode<T: Decodable>(_ type: T.Type, using decoder: JSONDecoder = JSONDecoder()) throws -> T {
        try decoder.decode(type, from: body)
    }

    /// A truncated, log-friendly excerpt of `body` for logging — `nil` for an empty or non-UTF-8 body.
    public var bodySnippet: String? {
        Self.bodySnippet(from: body)
    }

    static func bodySnippet(from data: Data, limit: Int = 512) -> String? {
        guard !data.isEmpty, let string = String(data: data, encoding: .utf8) else { return nil }
        guard string.count > limit else { return string }
        return String(string.prefix(limit)) + "… (truncated)"
    }
}

extension NetworkingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let reason):
            switch reason {
            case .invalidURL(let path):
                return "The request URL is invalid: \(path)."
            case .bodyEncodingFailed(let message):
                return "Failed to encode the request body: \(message)"
            case .parameterEncodingFailed(let message):
                return "Failed to encode the request parameters: \(message)"
            }
        case .transport(let error):
            return "A network error occurred: \(error.localizedDescription)"
        case .http(let error):
            return
                "The server returned status \(error.statusCode) (\(HTTPURLResponse.localizedString(forStatusCode: error.statusCode)))."
        case .decoding(let error, let metadata):
            return "Failed to decode the response (status \(metadata.statusCode)): \(error.detailedMessage)"
        case .validation(let reason, let metadata):
            return "The response (status \(metadata.statusCode)) failed validation: \(reason)"
        case .invalidResponse:
            return "The server returned a response that wasn't valid HTTP."
        case .cancelled:
            return "The request was cancelled."
        }
    }
}

extension DecodingError {
    var detailedMessage: String {
        var errorMessage = "Decoding error: "

        switch self {
        case .typeMismatch(let type, let context):
            errorMessage += "Type mismatch. Expected type \(type) but encountered an error."
            if !context.codingPath.isEmpty {
                let codingPath = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
                errorMessage += " Coding path: \(codingPath)."
            }
            if !context.debugDescription.isEmpty {
                errorMessage += " Debug description: \(context.debugDescription)"
            }
        case .valueNotFound(let type, let context):
            errorMessage += "Value not found for type \(type)."
            if !context.codingPath.isEmpty {
                let codingPath = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
                errorMessage += " Coding path: \(codingPath)."
            }
            if !context.debugDescription.isEmpty {
                errorMessage += " Debug description: \(context.debugDescription)"
            }
        case .keyNotFound(let key, let context):
            errorMessage += "Key '\(key.stringValue)' not found."
            if !context.codingPath.isEmpty {
                let codingPath = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
                errorMessage += " Coding path: \(codingPath)."
            }
            if !context.debugDescription.isEmpty {
                errorMessage += " Debug description: \(context.debugDescription)"
            }
        case .dataCorrupted(let context):
            errorMessage += "Data corrupted."
            if !context.codingPath.isEmpty {
                let codingPath = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
                errorMessage += " Coding path: \(codingPath)."
            }
            if !context.debugDescription.isEmpty {
                errorMessage += " Debug description: \(context.debugDescription)"
            }
        @unknown default:
            errorMessage += "Unknown decoding error occurred."
        }
        return errorMessage
    }
}
