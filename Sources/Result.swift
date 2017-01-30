import Foundation

public enum JSONResult {
    case success(SuccessJSONResponse)

    case failure(FailureJSONResponse)

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
            self = .failure(FailureJSONResponse(body: json, response: response, error: error))
        } else {
            self = .success(SuccessJSONResponse(body: json, response: response))
        }
    }
}

public enum ImageResult {
    case success(NetworkingImage, HTTPURLResponse)

    case failure(NSError, HTTPURLResponse)

    public init(image: NetworkingImage?, response: HTTPURLResponse, error: NSError?) {
        if let error = error {
            self = .failure(error, response)
        } else if let image = image {
            self = .success(image, response)
        } else {
            fatalError("No error, no image")
        }
    }
}

public enum DataResult {
    case success(Data, HTTPURLResponse)

    case failure(NSError, HTTPURLResponse)

    public init(data: Data?, response: HTTPURLResponse, error: NSError?) {
        if let error = error {
            self = .failure(error, response)
        } else if let data = data {
            self = .success(data, response)
        } else {
            fatalError("No data, no error")
        }
    }
}
