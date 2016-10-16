import Foundation

public extension Networking {

    /**
     POST request to the specified path, using the provided parameters.
     - parameter path: The path for the POST request.
     - parameter parameters: The parameters to be used, they will be serialized using the ParameterType, by default this is JSON.
     - parameter completion: A closure that gets called when the POST request is completed, it contains a `JSON` object and a `NSError`.
     - returns: The request identifier.
     */
    @discardableResult
    public func POST(_ path: String, parameterType: ParameterType = .json, parameters: Any? = nil, completion: @escaping (_ JSON: Any?, _ error: NSError?) -> ()) -> String {
        let requestID = self.request(.POST, path: path, parameterType: parameterType, parameters: parameters, parts: nil, responseType: .json) { JSON, headers, error in
            completion(JSON, error)
        }

        return requestID
    }

    /**
     POST request to the specified path, using the provided parameters.
     - parameter path: The path for the POST request.
     - parameter parameters: The parameters to be used, they will be serialized using the ParameterType, by default this is JSON.
     - parameter completion: A closure that gets called when the POST request is completed, it contains a `JSON` object and a `NSError`.
     - returns: The request identifier.
     */
    @discardableResult
    public func POST(_ path: String, parameterType: ParameterType = .json, parameters: Any? = nil, completion: @escaping (_ JSON: Any?, _ headers: [AnyHashable: Any], _ error: NSError?) -> ()) -> String {
        let requestID = self.request(.POST, path: path, parameterType: parameterType, parameters: parameters, parts: nil, responseType: .json, completion: completion)

        return requestID
    }

    /**
     POST request to the specified path, using the provided parameters.
     - parameter path: The path for the POST request.
     - parameter parameters: The parameters to be used, they will be serialized using the ParameterType, by default this is JSON.
     - parameter part: The form data that will be sent in the request.
     - parameter completion: A closure that gets called when the POST request is completed, it contains a `JSON` object and a `NSError`.
     - returns: The request identifier.
     */
    @discardableResult
    public func POST(_ path: String, parameters: Any? = nil, part: FormDataPart, completion: @escaping (_ JSON: Any?, _ error: NSError?) -> ()) -> String {
        let requestID = self.POST(path, parameters: parameters, parts: [part], completion: completion)

        return requestID
    }

    /**
     POST request to the specified path, using the provided parameters.
     - parameter path: The path for the POST request.
     - parameter parameters: The parameters to be used, they will be serialized using the ParameterType, by default this is JSON.
     - parameter parts: The list of form data parts that will be sent in the request.
     - parameter completion: A closure that gets called when the POST request is completed, it contains a `JSON` object and a `NSError`.
     - returns: The request identifier.
     */
    @discardableResult
    public func POST(_ path: String, parameters: Any? = nil, parts: [FormDataPart], completion: @escaping (_ JSON: Any?, _ error: NSError?) -> ()) -> String {
        let requestID = self.request(.POST, path: path, parameterType: .multipartFormData, parameters: parameters, parts: parts, responseType: .json) { JSON, headers, error in
            completion(JSON, error)
        }

        return requestID
    }

    /**
     Registers a fake POST request for the specified path. After registering this, every POST request to the path, will return the registered response.
     - parameter path: The path for the faked POST request.
     - parameter response: An `Any` that will be returned when a POST request is made to the specified path.
     - parameter statusCode: By default it's 200, if you provide any status code that is between 200 and 299 the response object will be returned, otherwise we will return an error containig the provided status code.
     */
    public func fakePOST(_ path: String, response: Any?, statusCode: Int = 200) {
        self.fake(.POST, path: path, response: response, responseType: .json, statusCode: statusCode)
    }

    /**
     Registers a fake POST request to the specified path using the contents of a file. After registering this, every POST request to the path, will return the contents of the registered file.
     - parameter path: The path for the faked POST request.
     - parameter fileName: The name of the file, whose contents will be registered as a reponse.
     - parameter bundle: The NSBundle where the file is located.
     */
    public func fakePOST(_ path: String, fileName: String, bundle: Bundle = Bundle.main) {
        self.fake(.POST, path: path, fileName: fileName, bundle: bundle)
    }

    /**
     Cancels the POST request for the specified path. This causes the request to complete with error code -999.
     - parameter path: The path for the cancelled POST request.
     - parameter completion: A closure that gets called when the cancellation is completed.
     */
    public func cancelPOST(_ path: String, completion: ((Void) -> Void)? = nil) {
        let url = self.url(for: path)
        self.cancelRequest(.Data, requestType: .POST, url: url, completion: completion)
    }
}
