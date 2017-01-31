import Foundation

public extension Networking {

    /// PUT request to the specified path, using the provided parameters.
    ///
    /// - Parameters:
    ///   - path: The path for the PUT request.
    ///   - parameterType: The parameters type to be used, by default is JSON.
    ///   - parameters: The parameters to be used, they will be serialized using the ParameterType, by default this is JSON.
    ///   - completion: The result of the operation, it's an enum with two cases: success and failure.
    /// - Returns: The request identifier.
    @discardableResult
    public func put(_ path: String, parameterType: ParameterType = .json, parameters: Any? = nil, completion: @escaping (_ result: JSONResult) -> Void) -> String {
        return requestJSON(requestType: .put, path: path, cacheName: nil, parameterType: parameterType, parameters: parameters, parts: nil, responseType: .json, completion: completion)
    }

    /// Registers a fake PUT request for the specified path. After registering this, every PUT request to the path, will return the registered response.
    ///
    /// - Parameters:
    ///   - path: The path for the faked PUT request.
    ///   - response: An `Any` that will be returned when a PUT request is made to the specified path.
    ///   - statusCode: By default it's 200, if you provide any status code that is between 200 and 299 the response object will be returned, otherwise we will return an error containig the provided status code.
    public func fakePUT(_ path: String, response: Any?, statusCode: Int = 200) {
        registerFake(requestType: .put, path: path, response: response, responseType: .json, statusCode: statusCode)
    }

    /// Registers a fake PUT request to the specified path using the contents of a file. After registering this, every PUT request to the path, will return the contents of the registered file.
    ///
    /// - Parameters:
    ///   - path: The path for the faked PUT request.
    ///   - fileName: The name of the file, whose contents will be registered as a reponse.
    ///   - bundle: The Bundle where the file is located.
    public func fakePUT(_ path: String, fileName: String, bundle: Bundle = Bundle.main) {
        registerFake(requestType: .put, path: path, fileName: fileName, bundle: bundle)
    }

    /// Cancels the PUT request for the specified path. This causes the request to complete with error code URLError.cancelled.
    ///
    /// - Parameter path: The path for the cancelled PUT request.
    public func cancelPUT(_ path: String) {
        let url = try! self.url(for: path)
        cancelRequest(.data, requestType: .put, url: url)
    }
}
