import Foundation

public extension Networking {
    /// Base initializer, it creates an instance of `Networking`.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for HTTP requests under `Networking`.
    ///   - configuration: The URLSessionConfiguration configuration to be used
    ///   - cache: The NSCache to use, it has a built-in default one.
    @objc(initWithBaseURL:) public convenience init(baseURL: String) {
        self.init(baseURL: baseURL, configuration: .default, cache: NSCache())
    }

    /// GET request to the specified path.
    ///
    /// - Parameters:
    ///   - path: The path for the GET request.
    ///   - parameters: The parameters to be used, they will be serialized using Percent-encoding and appended to the URL.
    ///   - completion: The result of the operation, it's an enum with two cases: success and failure.
    /// - Returns: The request identifier.
    @discardableResult
    @objc(get:parameters:completion:) public func __objc_get(_ path: String, parameters: Any?, completion: @escaping ((_ body: Any?, _ error: NSError?) -> ())) -> String {
        let parameterType: ParameterType = parameters != nil ? .formURLEncoded : .none

        return handleJSONRequest(.get, path: path, parameterType: parameterType, parameters: parameters, responseType: .json) { result in
            switch result {
            case let .success(response):
                let body = try! JSONSerialization.jsonObject(with: response.data, options: [])
                completion(body, nil)
            case let .failure(response):
                completion(nil, response.error)
            }
        }
    }
}
