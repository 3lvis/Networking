import Foundation

public enum Result {
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
