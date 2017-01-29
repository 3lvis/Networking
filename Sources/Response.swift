import Foundation

public class JSONResponse {
    public let body: JSON

    public var headers: [AnyHashable: Any] {
        return fullResponse.allHeaderFields
    }

    public var statusCode: Int {
        return fullResponse.statusCode
    }

    public var dictionaryBody: ([String: Any]) {
        return body.dictionary
    }

    public var arrayBody: ([[String: Any]]) {
        return body.array
    }

    public let fullResponse: HTTPURLResponse

    init(body: JSON, response: HTTPURLResponse) {
        self.body = body
        self.fullResponse = response
    }
}
