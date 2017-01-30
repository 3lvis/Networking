import Foundation

public class JSONResponse {
    public let body: JSON

    public var headers: [AnyHashable: Any] {
        return fullResponse.allHeaderFields
    }

    public var statusCode: Int {
        return fullResponse.statusCode
    }

    public var dictionaryBody: [String: Any] {
        return body.dictionary
    }

    public var arrayBody: [[String: Any]] {
        return body.array
    }

    public let fullResponse: HTTPURLResponse

    init(body: JSON, response: HTTPURLResponse) {
        self.body = body
        self.fullResponse = response
    }
}

public class SuccessJSONResponse: JSONResponse { }

public class FailureJSONResponse: JSONResponse {
    public let error: NSError

    init(body: JSON, response: HTTPURLResponse, error: NSError) {
        self.error = error

        super.init(body: body, response: response)
    }
}

public extension HTTPURLResponse {
    public var headers: [AnyHashable: Any] {
        return allHeaderFields
    }
}
