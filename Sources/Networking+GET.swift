import Foundation

public extension Networking {
    /**
    GET request to the specified path.
    - parameter path: The path for the GET request.
    - parameter completion: A closure that gets called when the GET request is completed, it contains a `JSON` object and a `NSError`.
    */
    public func GET(path: String, parameterType: ParameterType = .JSON, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        self.request(.GET, path: path, parameterType: parameterType, parameters: nil, parts: nil, responseType: .JSON) { JSON, headers, error in
            completion(JSON: JSON, error: error)
        }
    }

    /**
     GET request to the specified path.
     - parameter path: The path for the GET request.
     - parameter completion: A closure that gets called when the GET request is completed, it contains a `JSON` object and a `NSError`.
     */
    public func GET(path: String, parameterType: ParameterType = .JSON, completion: (JSON: AnyObject?, headers: [String : AnyObject], error: NSError?) -> ()) {
        self.request(.GET, path: path, parameterType: parameterType, parameters: nil, parts: nil, responseType: .JSON, completion: completion)
    }

    /**
     Registers a fake GET request for the specified path. After registering this, every GET request to the path, will return the registered response.
     - parameter path: The path for the faked GET request.
     - parameter response: An `AnyObject` that will be returned when a GET request is made to the specified path.
     - parameter statusCode: By default it's 200, if you provide any status code that is between 200 and 299 the response object will be returned, otherwise we will return an error containig the provided status code.
     */
    public func fakeGET(path: String, response: AnyObject?, statusCode: Int = 200) {
        self.fake(.GET, path: path, response: response, statusCode: statusCode)
    }

    /**
     Registers a fake GET request for the specified path using the contents of a file. After registering this, every GET request to the path, will return the contents of the registered file.
     - parameter path: The path for the faked GET request.
     - parameter fileName: The name of the file, whose contents will be registered as a reponse.
     - parameter bundle: The NSBundle where the file is located.
     */
    public func fakeGET(path: String, fileName: String, bundle: NSBundle = NSBundle.mainBundle()) {
        self.fake(.GET, path: path, fileName: fileName, bundle: bundle)
    }

    /**
     Cancels the GET request for the specified path. This causes the request to complete with error code -999.
     - parameter path: The path for the cancelled GET request
     */
    public func cancelGET(path: String) {
        let url = self.urlForPath(path)
        self.cancelRequest(.Data, requestType: .GET, url: url)
    }
}
