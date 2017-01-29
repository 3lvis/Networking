import Foundation

public enum JSONResult {
    case success(JSON, HTTPURLResponse)

    case failure(JSON, HTTPURLResponse, NSError)

    public init(_ json: JSON, _ response: HTTPURLResponse, _ error: NSError?) {
        if let error = error {
            self = .failure(json, response, error)
        } else {
            self = .success(json, response)
        }
    }
}

public enum ImageResult {
    case success(NetworkingImage, HTTPURLResponse)

    case failure(HTTPURLResponse, NSError)

    public init(_ image: NetworkingImage, _ response: HTTPURLResponse, _ error: NSError?) {
        if let error = error {
            self = .failure(response, error)
        } else {
            self = .success(image, response)
        }
    }
}

public enum DataResult {
    case success(Data, HTTPURLResponse)

    case failure(HTTPURLResponse, NSError)

    public init(_ data: Data, _ response: HTTPURLResponse, _ error: NSError?) {
        if let error = error {
            self = .failure(response, error)
        } else {
            self = .success(data, response)
        }
    }
}
