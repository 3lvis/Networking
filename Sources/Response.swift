import Foundation

public class Response {
    public var headers: [AnyHashable: Any] {
        return fullResponse.allHeaderFields
    }

    public var statusCode: Int {
        return fullResponse.statusCode
    }

    public let fullResponse: HTTPURLResponse

    init(response: HTTPURLResponse) {
        self.fullResponse = response
    }
}

public class FailureResponse: Response {
    public let error: NSError

    init(response: HTTPURLResponse, error: NSError) {
        self.error = error

        super.init(response: response)
    }
}

public class JSONResponse: Response {
    public let body: JSON

    public var dictionaryBody: [String: Any] {
        return body.dictionary
    }

    public var arrayBody: [[String: Any]] {
        return body.array
    }

    init(body: JSON, response: HTTPURLResponse) {
        self.body = body

        super.init(response: response)
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

public class SuccessImageResponse: Response {
    public let image: NetworkingImage

    init(image: NetworkingImage, response: HTTPURLResponse) {
        self.image = image

        super.init(response: response)
    }
}

public class SuccessDataResponse: Response {
    public let data: Data

    init(data: Data, response: HTTPURLResponse) {
        self.data = data

        super.init(response: response)
    }
}

public extension HTTPURLResponse {
    public var headers: [AnyHashable: Any] {
        return allHeaderFields
    }
}
