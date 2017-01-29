import Foundation

public enum JSONResult {
    case success(JSONResponse)

    case failure(NSError, JSONResponse)

    public init(response: JSONResponse, error: NSError?) {
        if let error = error {
            self = .failure(error, response)
        } else {
            self = .success(response)
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
