import Foundation

public extension Networking {
    /**
    POST request to the specified path, using the provided parameters.
    - parameter path: The path for the POST request.
    - parameter parameters: The parameters to be used, they will be serialized using the ParameterType, by 
     default this is JSON.
    - parameter completion: A closure that gets called when the POST request is completed, it contains a `JSON` object and a `NSError`.
    */
    public func POST(path: String, parameterType: ParameterType = .JSON, parameters: AnyObject? = nil, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        self.request(.POST, path: path, parameterType: parameterType, parameters: parameters, parts: nil, responseType: .JSON) { JSON, headers, error in
            completion(JSON: JSON, error: error)
        }
    }

    /**
     POST request to the specified path, using the provided parameters.
     - parameter path: The path for the POST request.
     - parameter parameters: The parameters to be used, they will be serialized using the ParameterType, by
     default this is JSON.
     - parameter completion: A closure that gets called when the POST request is completed, it contains a `JSON` object and a `NSError`.
     */
    public func POST(path: String, parameterType: ParameterType = .JSON, parameters: AnyObject? = nil, completion: (JSON: AnyObject?, headers: [String : AnyObject], error: NSError?) -> ()) {
        self.request(.POST, path: path, parameterType: parameterType, parameters: parameters, parts: nil, responseType: .JSON, completion: completion)
    }

    /**
     POST request to the specified path, using the provided parameters.
     - parameter path: The path for the POST request.
     - parameter parameters: The parameters to be used, they will be serialized using the ParameterType, by
     default this is JSON.
     - parameter part: The form data that will be sent in the request.
     - parameter completion: A closure that gets called when the POST request is completed, it contains a `JSON` object and a `NSError`.
     */
    public func POST(path: String, parameters: AnyObject? = nil, part: FormDataPart, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        self.POST(path, parameters: parameters, parts: [part], completion: completion)
    }

    /**
     POST request to the specified path, using the provided parameters.
     - parameter path: The path for the POST request.
     - parameter parameters: The parameters to be used, they will be serialized using the ParameterType, by
     default this is JSON.
     - parameter parts: The list of form data parts that will be sent in the request.
     - parameter completion: A closure that gets called when the POST request is completed, it contains a `JSON` object and a `NSError`.
     */
    public func POST(path: String, parameters: AnyObject? = nil, parts: [FormDataPart], completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        self.request(.POST, path: path, parameterType: .MultipartFormData, parameters: parameters, parts: parts, responseType: .JSON) { JSON, headers, error in
            completion(JSON: JSON, error: error)
        }
    }

    /**
     Registers a fake POST request for the specified path. After registering this, every POST request to the path, will return the registered response.
     - parameter path: The path for the faked POST request.
     - parameter response: An `AnyObject` that will be returned when a POST request is made to the specified path.
     - parameter statusCode: By default it's 200, if you provide any status code that is between 200 and 299 the response object will be returned, otherwise we will return an error containig the provided status code.
     */
    public func fakePOST(path: String, response: AnyObject?, statusCode: Int = 200) {
        self.fake(.POST, path: path, response: response, statusCode: statusCode)
    }

    /**
     Registers a fake POST request to the specified path using the contents of a file. After registering this, every POST request to the path, will return the contents of the registered file.
     - parameter path: The path for the faked POST request.
     - parameter fileName: The name of the file, whose contents will be registered as a reponse.
     - parameter bundle: The NSBundle where the file is located.
     */
    public func fakePOST(path: String, fileName: String, bundle: NSBundle = NSBundle.mainBundle()) {
        self.fake(.POST, path: path, fileName: fileName, bundle: bundle)
    }

    /**
     Cancels the POST request for the specified path. This causes the request to complete with error code -999.
     - parameter path: The path for the cancelled POST request.
     */
    public func cancelPOST(path: String) {
        let url = self.urlForPath(path)
        self.cancelRequest(.Data, requestType: .POST, url: url)
    }
}
