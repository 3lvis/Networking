import Foundation

public extension Networking {

    /// GET request to the specified path.
    ///
    /// - Parameters:
    ///   - path: The path for the GET request.
    ///   - parameters: The parameters to be used, they will be serialized using Percent-encoding and appended to the URL.
    ///   - completion: The result of the operation, it's an enum with two cases: success and failure.
    /// - Returns: The request identifier.
    @discardableResult
    public func get(_ path: String, parameters: Any? = nil, completion: @escaping (_ result: JSONResult) -> Void) -> String {
        let parameterType = parameters != nil ? ParameterType.formURLEncoded : ParameterType.none

        return jsonRequest(.get, path: path, cacheName: nil, parameterType: parameterType, parameters: parameters, parts: nil, responseType: .json, completion: completion)
    }

    /// Registers a fake GET request for the specified path. After registering this, every GET request to the path, will return the registered response.
    ///
    /// - Parameters:
    ///   - path: The path for the faked GET request.
    ///   - response: An `Any` that will be returned when a GET request is made to the specified path.
    ///   - statusCode: By default it's 200, if you provide any status code that is between 200 and 299 the response object will be returned, otherwise we will return an error containig the provided status code.
    public func fakeGET(_ path: String, response: Any?, statusCode: Int = 200) {
        fake(.get, path: path, response: response, responseType: .json, statusCode: statusCode)
    }

    /// Registers a fake GET request for the specified path using the contents of a file. After registering this, every GET request to the path, will return the contents of the registered file.
    ///
    /// - Parameters:
    ///   - path: The path for the faked GET request.
    ///   - fileName: The name of the file, whose contents will be registered as a reponse.
    ///   - bundle: The Bundle where the file is located.
    public func fakeGET(_ path: String, fileName: String, bundle: Bundle = Bundle.main) {
        fake(.get, path: path, fileName: fileName, bundle: bundle)
    }

    /// Cancels the GET request for the specified path. This causes the request to complete with error code URLError.cancelled.
    ///
    /// - Parameter path: The path for the cancelled GET request
    public func cancelGET(_ path: String) {
        let url = try! self.url(for: path)
        cancelRequest(.data, requestType: .get, url: url)
    }
}
