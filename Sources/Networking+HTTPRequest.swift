import Foundation

// MARK: GET
public extension Networking {
    /**
    GET request to the specified path.
    - parameter path: The path for the GET request.
    - parameter completion: A closure that gets called when the GET request is completed, it contains a `JSON` object and a `NSError`.
    */
    public func GET(_ path: String, contentType: ContentType = .json, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        self.request(.GET, path: path, contentType: contentType, parameters: nil, completion: completion)
    }

    /**
     Registers a fake GET request for the specified path. After registering this, every GET request to the path, will return
     the registered response.
     - parameter path: The path for the faked GET request.
     - parameter response: An `AnyObject` that will be returned when a GET request is made to the specified path.
     - parameter statusCode: By default it's 200, if you provide any status code that is between 200 and 299 the
     response object will be returned, otherwise we will return an error containig the provided status code.
     */
    public func fakeGET(_ path: String, response: AnyObject?, statusCode: Int = 200) {
        self.fake(.GET, path: path, response: response, statusCode: statusCode)
    }

    /**
     Registers a fake GET request for the specified path using the contents of a file. After registering this, every GET request to the path, will return
     the contents of the registered file.
     - parameter path: The path for the faked GET request.
     - parameter fileName: The name of the file, whose contents will be registered as a reponse.
     - parameter bundle: The NSBundle where the file is located.
     */
    public func fakeGET(_ path: String, fileName: String, bundle: Bundle = Bundle.main()) {
        self.fake(.GET, path: path, fileName: fileName, bundle: bundle)
    }

    /**
     Cancels the GET request for the specified path. This causes the request to complete with error code -999
     - parameter path: The path for the cancelled GET request
     */
    public func cancelGET(_ path: String) {
        let url = self.urlForPath(path)
        self.cancelRequest(.Data, requestType: .GET, url: url)
    }
}

// MARK: - POST
public extension Networking {
    /**
    POST request to the specified path, using the provided parameters.
    - parameter path: The path for the POST request.
    - parameter parameters: The parameters to be used, they will be serialized using NSJSONSerialization.
    - parameter completion: A closure that gets called when the POST request is completed, it contains a `JSON` object and a `NSError`.
    */
    public func POST(_ path: String, contentType: ContentType = .json, parameters: AnyObject? = nil, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        self.request(.POST, path: path, contentType: contentType, parameters: parameters, completion: completion)
    }

    /**
     Registers a fake POST request for the specified path. After registering this, every POST request to the path, will return
     the registered response.
     - parameter path: The path for the faked POST request.
     - parameter response: An `AnyObject` that will be returned when a POST request is made to the specified path.
     - parameter statusCode: By default it's 200, if you provide any status code that is between 200 and 299 the
     response object will be returned, otherwise we will return an error containig the provided status code.
     */
    public func fakePOST(_ path: String, response: AnyObject?, statusCode: Int = 200) {
        self.fake(.POST, path: path, response: response, statusCode: statusCode)
    }

    /**
     Registers a fake POST request to the specified path using the contents of a file. After registering this, every POST request to the path, will return
     the contents of the registered file.
     - parameter path: The path for the faked POST request.
     - parameter fileName: The name of the file, whose contents will be registered as a reponse.
     - parameter bundle: The NSBundle where the file is located.
     */
    public func fakePOST(_ path: String, fileName: String, bundle: Bundle = Bundle.main()) {
        self.fake(.POST, path: path, fileName: fileName, bundle: bundle)
    }

    /**
     Cancels the POST request for the specified path. This causes the request to complete with error code -999
     - parameter path: The path for the cancelled POST request
     */
    public func cancelPOST(_ path: String) {
        let url = self.urlForPath(path)
        self.cancelRequest(.Data, requestType: .POST, url: url)
    }
}

// MARK: - PUT
public extension Networking {
    /**
    PUT request to the specified path, using the provided parameters.
    - parameter path: The path for the PUT request.
    - parameter parameters: The parameters to be used, they will be serialized using NSJSONSerialization.
    - parameter completion: A closure that gets called when the PUT request is completed, it contains a `JSON` object and a `NSError`.
    */
    public func PUT(_ path: String, contentType: ContentType = .json, parameters: AnyObject?, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        self.request(.PUT, path: path, contentType: contentType, parameters: parameters, completion: completion)
    }

    /**
     Registers a fake PUT request for the specified path. After registering this, every PUT request to the path, will return
     the registered response.
     - parameter path: The path for the faked PUT request.
     - parameter response: An `AnyObject` that will be returned when a PUT request is made to the specified path.
     - parameter statusCode: By default it's 200, if you provide any status code that is between 200 and 299 the
     response object will be returned, otherwise we will return an error containig the provided status code.
     */
    public func fakePUT(_ path: String, response: AnyObject?, statusCode: Int = 200) {
        self.fake(.PUT, path: path, response: response, statusCode: statusCode)
    }

    /**
     Registers a fake PUT request to the specified path using the contents of a file. After registering this, every PUT request to the path, will return
     the contents of the registered file.
     - parameter path: The path for the faked PUT request.
     - parameter fileName: The name of the file, whose contents will be registered as a reponse.
     - parameter bundle: The NSBundle where the file is located.
     */
    public func fakePUT(_ path: String, fileName: String, bundle: Bundle = Bundle.main()) {
        self.fake(.PUT, path: path, fileName: fileName, bundle: bundle)
    }

    /**
     Cancels the PUT request for the specified path. This causes the request to complete with error code -999
     - parameter path: The path for the cancelled PUT request
     */
    public func cancelPUT(_ path: String) {
        let url = self.urlForPath(path)
        self.cancelRequest(.Data, requestType: .PUT, url: url)
    }
}

// MARK: - DELETE
public extension Networking {
    /**
    DELETE request to the specified path, using the provided parameters.
    - parameter path: The path for the DELETE request.
    - parameter completion: A closure that gets called when the DELETE request is completed, it contains a `JSON` object and a `NSError`.
    */
    public func DELETE(_ path: String, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        self.request(.DELETE, path: path, contentType: .json, parameters: nil, completion: completion)
    }

    /**
     Registers a fake DELETE request for the specified path. After registering this, every DELETE request to the path, will return
     the registered response.
     - parameter path: The path for the faked DELETE request.
     - parameter response: An `AnyObject` that will be returned when a DELETE request is made to the specified path.
     - parameter statusCode: By default it's 200, if you provide any status code that is between 200 and 299 the
     response object will be returned, otherwise we will return an error containig the provided status code.
     */
    public func fakeDELETE(_ path: String, response: AnyObject?, statusCode: Int = 200) {
        self.fake(.DELETE, path: path, response: response, statusCode: statusCode)
    }

    /**
     Registers a fake DELETE request to the specified path using the contents of a file. After registering this, every DELETE request to the path, will return
     the contents of the registered file.
     - parameter path: The path for the faked DELETE request.
     - parameter fileName: The name of the file, whose contents will be registered as a reponse.
     - parameter bundle: The NSBundle where the file is located.
     */
    public func fakeDELETE(_ path: String, fileName: String, bundle: Bundle = Bundle.main()) {
        self.fake(.DELETE, path: path, fileName: fileName, bundle: bundle)
    }

    /**
     Cancels the DELETE request for the specified path. This causes the request to complete with error code -999
     - parameter path: The path for the cancelled DELETE request
     */
    public func cancelDELETE(_ path: String) {
        let url = self.urlForPath(path)
        self.cancelRequest(.Data, requestType: .DELETE, url: url)
    }
}
