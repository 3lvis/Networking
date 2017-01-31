import Foundation

public extension Networking {

    /// DELETE request to the specified path, using the provided parameters.
    ///
    /// - Parameters:
    ///   - path: The path for the DELETE request.
    ///   - parameters: The parameters to be used, they will be serialized using Percent-encoding and appended to the URL.
    ///   - completion: The result of the operation, it's an enum with two cases: success and failure.
    /// - Returns: The request identifier.
    @discardableResult
    public func delete(_ path: String, parameters: Any? = nil, completion: @escaping (_ result: JSONResult) -> Void) -> String {
        let parameterType = parameters != nil ? ParameterType.formURLEncoded : ParameterType.none
        return jsonRequest(.delete, path: path, cacheName: nil, parameterType: parameterType, parameters: parameters, parts: nil, responseType: .json, completion: completion)
    }

    /// Registers a fake DELETE request for the specified path. After registering this, every DELETE request to the path, will return the registered response.
    ///
    /// - Parameters:
    ///   - path: The path for the faked DELETE request.
    ///   - response: An `Any` that will be returned when a DELETE request is made to the specified path.
    ///   - statusCode: By default it's 200, if you provide any status code that is between 200 and 299 the response object will be returned, otherwise we will return an error containig the provided status code.
    public func fakeDELETE(_ path: String, response: Any?, statusCode: Int = 200) {
        registerFake(.delete, path: path, response: response, responseType: .json, statusCode: statusCode)
    }

    /// Registers a fake DELETE request to the specified path using the contents of a file. After registering this, every DELETE request to the path, will return the contents of the registered file.
    ///
    /// - Parameters:
    ///   - path: The path for the faked DELETE request.
    ///   - fileName: The name of the file, whose contents will be registered as a reponse.
    ///   - bundle: The Bundle where the file is located.
    public func fakeDELETE(_ path: String, fileName: String, bundle: Bundle = Bundle.main) {
        registerFake(.delete, path: path, fileName: fileName, bundle: bundle)
    }

    /// Cancels the DELETE request for the specified path. This causes the request to complete with error code URLError.cancelled.
    ///
    /// - Parameter path: The path for the cancelled DELETE request.
    public func cancelDELETE(_ path: String) {
        let url = try! self.url(for: path)
        cancelRequest(.data, requestType: .delete, url: url)
    }
}
