import Foundation

public enum NetworkingError: Error {
    case invalidURL
    case invalidResponse
    case clientError(statusCode: Int, message: String)
    case serverError(statusCode: Int, message: String, details: [String: Any]?)
    case unexpectedError(statusCode: Int?, message: String)
}

extension NetworkingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "We're sorry, but the URL for this request is invalid."
        case .invalidResponse:
            return "We're sorry, but we received an invalid response from the server."
        case .clientError(let statusCode, let message):
            return "We're sorry, but a client error occurred. Code: \(statusCode), \(message)."
        case .serverError(let statusCode, let message, let details):
            var detailsString = ""
            if let details = details {
                detailsString = details.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            }
            return "We're sorry, but a server error occurred. Code: \(statusCode) \(message). Additional info: \(detailsString)"
        case .unexpectedError(let statusCode, let message):
            let statusCodeMessage = statusCode != nil ? "Code: \(statusCode!). " : ""
            return "We're sorry, but an unexpected error occurred. \(statusCodeMessage)\(message)"
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
