import Foundation

public extension Networking {

    /// POST request to the specified path, using the provided parameters.
    ///
    /// - Parameters:
    ///   - path: The path for the POST request.
    ///   - parameterType: The parameters type to be used, by default is JSON.
    ///   - parameters: The parameters to be used, they will be serialized using the ParameterType, by default this is JSON.
    ///   - completion: The result of the operation, it's an enum with two cases: success and failure.
    /// - Returns: The request identifier.
    @discardableResult
    public func post(_ path: String, parameterType: ParameterType = .json, parameters: Any? = nil, completion: @escaping (_ result: JSONResult) -> Void) -> String {
        return jsonRequest(.post, path: path, cacheName: nil, parameterType: parameterType, parameters: parameters, parts: nil, responseType: .json, completion: completion)
    }

    /// POST request to the specified path, using the provided parameters.
    ///
    /// - Parameters:
    ///   - path: The path for the POST request.
    ///   - parameters: The parameters to be used, they will be serialized using the ParameterType, by default this is JSON.
    ///   - parts: The list of form data parts that will be sent in the request.
    ///   - completion: A closure that gets called when the POST request is completed, it contains a `JSON` object and an `NSError`.
    /// - Returns: The request identifier.
    @discardableResult
    public func post(_ path: String, parameters: Any? = nil, parts: [FormDataPart], completion: @escaping (_ result: JSONResult) -> Void) -> String {
        return jsonRequest(.post, path: path, cacheName: nil, parameterType: .multipartFormData, parameters: parameters, parts: parts, responseType: .json, completion: completion)
    }

    /// Registers a fake POST request for the specified path. After registering this, every POST request to the path, will return the registered response.
    ///
    /// - Parameters:
    ///   - path: The path for the faked POST request.
    ///   - response: An `Any` that will be returned when a POST request is made to the specified path.
    ///   - statusCode: By default it's 200, if you provide any status code that is between 200 and 299 the response object will be returned, otherwise we will return an error containig the provided status code.
    public func fakePOST(_ path: String, response: Any?, statusCode: Int = 200) {
        fake(.post, path: path, response: response, responseType: .json, statusCode: statusCode)
    }

    /// Registers a fake POST request to the specified path using the contents of a file. After registering this, every POST request to the path, will return the contents of the registered file.
    ///
    /// - Parameters:
    ///   - path: The path for the faked POST request.
    ///   - fileName: The name of the file, whose contents will be registered as a reponse.
    ///   - bundle: The Bundle where the file is located.
    public func fakePOST(_ path: String, fileName: String, bundle: Bundle = Bundle.main) {
        fake(.post, path: path, fileName: fileName, bundle: bundle)
    }

    /// Cancels the POST request for the specified path. This causes the request to complete with error code URLError.cancelled.
    ///
    /// - Parameter path: The path for the cancelled POST request.
    public func cancelPOST(_ path: String) {
        let url = try! self.url(for: path)
        cancelRequest(.data, requestType: .post, url: url)
    }
}
