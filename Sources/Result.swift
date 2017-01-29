import Foundation

public enum JSONResult {
    case success(JSON, HTTPURLResponse)

    case failure(NSError, JSON, HTTPURLResponse)

    public init(json: JSON, response: HTTPURLResponse, error: NSError?) {
        if let error = error {
            self = .failure(error, json, response)
        } else {
            self = .success(json, response)
        }
    }
}

public enum ImageResult {
    case success(NetworkingImage, HTTPURLResponse)

    case failure(HTTPURLResponse, NSError)

    public init(image: NetworkingImage?, response: HTTPURLResponse, error: NSError?) {
        if let error = error {
            self = .failure(response, error)
        } else if let image = image {
            self = .success(image, response)
        } else {
            fatalError("No error, no image")
        }
    }
}

public enum DataResult {
    case success(Data, HTTPURLResponse)

    case failure(HTTPURLResponse, NSError)

    public init(data: Data?, response: HTTPURLResponse, error: NSError?) {
        if let error = error {
            self = .failure(response, error)
        } else if let data = data {
            self = .success(data, response)
        } else {
            fatalError("No data, no error")
        }
    }
}
