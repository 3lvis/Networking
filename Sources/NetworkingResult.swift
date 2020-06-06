import Foundation

public protocol NetworkingResult {
    init(body: Any?, response: HTTPURLResponse, error: NSError?)
}

public enum GenericResult<T> {
    case success(T)
    case failure(FailureJSONResponse)
}

public enum VoidResult {
    case success
    case failure(FailureJSONResponse)
}

public enum JSONResult: NetworkingResult {
    case success(SuccessJSONResponse)

    case failure(FailureJSONResponse)

    public var error: NSError? {
        switch self {
        case .success:
            return nil
        case let .failure(response):
            return response.error
        }
    }

    public init(body: Any?, response: HTTPURLResponse, error: NSError?) {
        var returnedError = error
        var json = JSON.none

        if let dictionary = body as? [String: Any] {
            json = JSON(dictionary)
        } else if let array = body as? [[String: Any]] {
            json = JSON(array)
        } else if let data = body as? Data, data.count > 0 {
            do {
                json = try JSON(data)
            } catch let JSONParsingError as NSError {
                if returnedError == nil {
                    returnedError = JSONParsingError
                }
            }
        }

        if let finalError = returnedError {
            self = .failure(FailureJSONResponse(json: json, response: response, error: finalError))
        } else {
            self = .success(SuccessJSONResponse(json: json, response: response, body: body))
        }
    }
}

public enum ImageResult: NetworkingResult {
    case success(SuccessImageResponse)

    case failure(FailureResponse)

    public init(body: Any?, response: HTTPURLResponse, error: NSError?) {
        let image = body as? Image
        if let error = error {
            self = .failure(FailureResponse(response: response, error: error))
        } else if let image = image {
            self = .success(SuccessImageResponse(image: image, response: response))
        } else {
            let error = NSError(domain: Networking.domain, code: URLError.cannotParseResponse.rawValue, userInfo: [NSLocalizedDescriptionKey: "Malformed image"])
            self = .failure(FailureResponse(response: response, error: error))
        }
    }
}

public enum DataResult: NetworkingResult {
    case success(SuccessDataResponse)

    case failure(FailureResponse)

    public init(body: Any?, response: HTTPURLResponse, error: NSError?) {
        let data = body as? Data
        if let error = error {
            self = .failure(FailureResponse(response: response, error: error))
        } else if let data = data {
            self = .success(SuccessDataResponse(data: data, response: response))
        } else {
            let error = NSError(domain: Networking.domain, code: URLError.cannotParseResponse.rawValue, userInfo: [NSLocalizedDescriptionKey: "Malformed data"])
            self = .failure(FailureResponse(response: response, error: error))
        }
    }
}
