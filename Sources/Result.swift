import Foundation

public enum JSONResult {
    case success(SuccessJSONResponse)

    case failure(FailureJSONResponse)

    public var error: NSError? {
        switch self {
        case .success:
            return nil
        case .failure(let response):
            return response.error
        }
    }

    public init(body: Any?, response: HTTPURLResponse, error: NSError?) {
        var json: JSON
        
        if let dictionary = body as? [String: Any] {
            json = JSON(dictionary)
        } else if let array = body as? [[String: Any]] {
            json = JSON(array)
        } else {
            json = JSON.none
        }

        if let error = error {
            self = .failure(FailureJSONResponse(json: json, response: response, error: error))
        } else {
            self = .success(SuccessJSONResponse(json: json, response: response))
        }
    }
}

public enum ImageResult {
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

public enum DataResult {
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
