import Foundation

/// A request failure, categorized by where it happened so callers can inspect the underlying cause
/// rather than parse a stringified catch-all.
public enum NetworkingError: Error {
    /// The request couldn't be built or its body/parameters couldn't be encoded — a caller-side bug.
    case invalidRequest(InvalidRequestReason)
    /// The request never produced an HTTP response: offline, DNS failure, TLS failure, timeout, etc.
    /// Carries the underlying `URLError`.
    case transport(URLError)
    /// An HTTP response arrived with a non-2xx status code. Carries the status, response metadata, and
    /// any message parsed from the error body.
    case http(HTTPError)
    /// A response arrived but its body couldn't be decoded into the requested type. Carries the
    /// underlying `DecodingError` and the response metadata for debugging.
    case decoding(DecodingError, ResponseMetadata)
    /// A 2xx response failed a registered validator (wrong content-type, bad envelope, …) — structurally
    /// fine but not acceptable. Carries the reason and the response metadata.
    case validation(reason: String, ResponseMetadata)
    /// The response wasn't an HTTP response at all.
    case invalidResponse
    /// The request was cancelled.
    case cancelled
}

public extension NetworkingError {
    /// The HTTP status code, when the failure carries one (`.http` or `.decoding`).
    var statusCode: Int? {
        switch self {
        case let .http(error): return error.statusCode
        case let .decoding(_, metadata): return metadata.statusCode
        case let .validation(_, metadata): return metadata.statusCode
        default: return nil
        }
    }

    /// Whether this is a cancellation — used to skip logging intentional cancels as errors.
    var isCancelled: Bool {
        if case .cancelled = self { return true }
        return false
    }

    /// The response metadata, when the failure carries a response (`.http` or `.decoding`).
    var responseMetadata: ResponseMetadata? {
        switch self {
        case let .http(error): return error.metadata
        case let .decoding(_, metadata): return metadata
        case let .validation(_, metadata): return metadata
        default: return nil
        }
    }

    /// The default statuses `RetryInterceptor` retries, and the source of truth for `isRetryable`.
    static let retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504]

    /// Whether a transport failure is transient (a dropped connection or timeout) and so worth retrying.
    static func isRetryableTransport(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    /// Whether retrying the request might plausibly succeed. Conservative: only transient transport
    /// failures and a small set of HTTP status codes (408, 429, 500, 502, 503, 504) — never 4xx
    /// (other than 408/429), decoding, invalid-request, invalid-response, or cancellation.
    var isRetryable: Bool {
        switch self {
        case let .transport(error):
            return Self.isRetryableTransport(error)
        case let .http(error):
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
    /// A human-readable message parsed from a recognized error body, when present.
    public let serverMessage: String?

    public init(statusCode: Int, metadata: ResponseMetadata, serverMessage: String?) {
        self.statusCode = statusCode
        self.metadata = metadata
        self.serverMessage = serverMessage
    }

    public var isClientError: Bool { (400 ..< 500).contains(statusCode) }
    public var isServerError: Bool { (500 ..< 600).contains(statusCode) }
}

/// Metadata about an HTTP response, retained on failures for logging and debugging.
public struct ResponseMetadata: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    /// A truncated, log-friendly snippet of the response body — not the full payload. May still contain
    /// sensitive data, so treat it as you would any request/response contents.
    public let bodySnippet: String?

    public init(statusCode: Int, headers: [String: String], bodySnippet: String?) {
        self.statusCode = statusCode
        self.headers = headers
        self.bodySnippet = bodySnippet
    }

    /// Builds metadata from a response and its body, truncating the body to a log-friendly snippet.
    public init(response: HTTPURLResponse, body: Data) {
        let headers = Dictionary(uniqueKeysWithValues: response.allHeaderFields.compactMap { key, value in
            (key as? String).map { ($0, "\(value)") }
        })
        self.init(statusCode: response.statusCode, headers: headers, bodySnippet: Self.bodySnippet(from: body))
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
        case let .invalidRequest(reason):
            switch reason {
            case let .invalidURL(path):
                return "The request URL is invalid: \(path)."
            case let .bodyEncodingFailed(message):
                return "Failed to encode the request body: \(message)"
            case let .parameterEncodingFailed(message):
                return "Failed to encode the request parameters: \(message)"
            }
        case let .transport(error):
            return "A network error occurred: \(error.localizedDescription)"
        case let .http(error):
            if let serverMessage = error.serverMessage, !serverMessage.isEmpty {
                return "The server returned status \(error.statusCode): \(serverMessage)"
            }
            return "The server returned status \(error.statusCode) (\(HTTPURLResponse.localizedString(forStatusCode: error.statusCode)))."
        case let .decoding(error, metadata):
            return "Failed to decode the response (status \(metadata.statusCode)): \(error.detailedMessage)"
        case let .validation(reason, metadata):
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

public struct ErrorResponse: Decodable {
    let error: String?
    let message: String?
    let errors: [String: [String]]?

    var combinedMessage: String {
        var messages = [String]()
        if let error = error {
            messages.append(error)
        }
        if let message = message {
            messages.append(message)
        }
        if let errors = errors {
            for (_, messagesArray) in errors {
                let combinedFieldMessages = messagesArray.joined(separator: ", ")
                messages.append(combinedFieldMessages)
            }
        }
        return messages.joined(separator: "; ")
    }
}

/*
 1. Validation Errors
 These occur when user input does not meet validation criteria.
{
    "errors": {
        "start_time": ["Start time can't be blank"],
        "end_time": ["End time can't be blank"],
        "base": ["Availability duration must be at least 240 minutes."]
    }
}

2. Authentication Errors
These occur when authentication credentials are missing or invalid.
{
    "errors": {
        "authentication": ["Invalid credentials", "Token has expired"]
    }
}

3. Authorization Errors
These occur when a user tries to access a resource they don't have permission to access.
{
    "errors": {
        "authorization": ["You do not have permission to access this resource"]
    }
}

4. Resource Not Found Errors
These occur when a requested resource cannot be found.
{
    "errors": {
        "not_found": ["Resource not found"]
    }
}

5. Conflict Errors
These occur when there is a conflict with the current state of the resource.


{
    "errors": {
        "conflict": ["Resource already exists", "Update conflict detected"]
    }
}

6. Rate Limiting Errors
These occur when a user exceeds the rate limit for API requests.

{
    "errors": {
        "rate_limit": ["Too many requests, please try again later"]
    }
}

7. Server Errors
These occur when there is an internal server error.

{
    "errors": {
        "server": ["An internal server error occurred. Please try again later"]
    }
}

8. Service Unavailable Errors
These occur when the service is temporarily unavailable.

{
    "errors": {
        "service_unavailable": ["The service is temporarily unavailable. Please try again later"]
    }
}

9. Bad Request Errors
These occur when the server cannot process the request due to client error (e.g., malformed request syntax).

{
    "errors": {
        "bad_request": ["Invalid request format", "Missing required parameters"]
    }
}

10. Unsupported Media Type Errors
These occur when the media type of the request is not supported by the server.

{
    "errors": {
        "unsupported_media_type": ["The media type is not supported"]
    }
}

11. Unprocessable Entity Errors
These occur when the server understands the content type of the request entity but was unable to process the contained instructions.

{
    "errors": {
        "unprocessable_entity": ["Validation failed", "Invalid data format"]
    }
}

12. Dependency Errors
These occur when the application depends on an external service which fails.

{
    "errors": {
        "dependency": ["External service error. Please try again later"]
    }
}

13. Method Not Allowed Errors
These occur when the HTTP method is not allowed for the requested resource.

{
    "errors": {
        "method_not_allowed": ["The HTTP method is not allowed for this resource"]
    }
}

14. Gone Errors
These occur when the resource requested is no longer available and will not be available again.

{
    "errors": {
        "gone": ["The resource requested is no longer available"]
    }
}

15. Custom Application Errors
These occur when the application defines specific custom errors.

{
    "errors": {
        "custom_error": ["Custom application-specific error message"]
    }
}

Combining Multiple Error Types
In some cases, you may need to include multiple types of errors in a single response.

{
    "errors": {
        "validation": {
            "start_time": ["Start time can't be blank"],
            "end_time": ["End time can't be blank"]
        },
        "authentication": ["Invalid token"]
    }
}
*/
