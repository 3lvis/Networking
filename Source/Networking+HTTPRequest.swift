import Foundation

// MARK: GET
public extension Networking {
    /**
    GET request to the specified path.
    - parameter path: The path for the GET request.
    - parameter completion: A closure that gets called when the GET request is completed, it contains a `JSON` object and a `NSError`.
    */
    public func GET(path: String, contentType: ContentType = .JSON, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        self.request(.GET, path: path, contentType: contentType, parameters: nil, completion: completion)
    }

    /**
     Cancels the GET request for the specified path. This causes the request to complete with error code -999
     - parameter path: The path for the cancelled GET request
     */
    public func cancelGET(path: String) {
        self.cancelRequest(.Data, requestType: .GET, path: path)
    }

    /**
     Stubs GET request for the specified path. After registering this, every GET request to the path, will return
     the registered response.
     - parameter path: The path for the stubbed GET request.
     - parameter response: An `AnyObject` that will be returned when a GET request is made to the specified path.
     */
    public func stubGET(path: String, response: AnyObject?, failed: Bool = false) {
        self.stub(.GET, path: path, response: response, failed: failed)
    }

    /**
     Stubs GET request for the specified path using the contents of a file. After registering this, every GET request to the path, will return
     the contents of the registered file.
     - parameter path: The path for the stubbed GET request.
     - parameter fileName: The name of the file, whose contents will be registered as a reponse.
     - parameter bundle: The NSBundle where the file is located.
     */
    public func stubGET(path: String, fileName: String, bundle: NSBundle = NSBundle.mainBundle()) {
        self.stub(.GET, path: path, fileName: fileName, bundle: bundle)
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
    public func POST(path: String, contentType: ContentType = .JSON, parameters: AnyObject?, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        self.request(.POST, path: path, contentType: contentType, parameters: parameters, completion: completion)
    }

    /**
     Cancels the POST request for the specified path. This causes the request to complete with error code -999
     - parameter path: The path for the cancelled POST request
     */
    public func cancelPOST(path: String) {
        self.cancelRequest(.Data, requestType: .POST, path: path)
    }

    /**
     Stubs POST request for the specified path. After registering this, every POST request to the path, will return
     the registered response.
     - parameter path: The path for the stubbed POST request.
     - parameter response: An `AnyObject` that will be returned when a POST request is made to the specified path.
     */
    public func stubPOST(path: String, response: AnyObject?, failed: Bool = false) {
        self.stub(.POST, path: path, response: response, failed: failed)
    }

    /**
     Stubs POST request to the specified path using the contents of a file. After registering this, every POST request to the path, will return
     the contents of the registered file.
     - parameter path: The path for the stubbed POST request.
     - parameter fileName: The name of the file, whose contents will be registered as a reponse.
     - parameter bundle: The NSBundle where the file is located.
     */
    public func stubPOST(path: String, fileName: String, bundle: NSBundle = NSBundle.mainBundle()) {
        self.stub(.POST, path: path, fileName: fileName, bundle: bundle)
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
    public func PUT(path: String, contentType: ContentType = .JSON, parameters: AnyObject?, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        self.request(.PUT, path: path, contentType: contentType, parameters: parameters, completion: completion)
    }

    /**
     Cancels the PUT request for the specified path. This causes the request to complete with error code -999
     - parameter path: The path for the cancelled PUT request
     */
    public func cancelPUT(path: String) {
        self.cancelRequest(.Data, requestType: .PUT, path: path)
    }

    /**
     Stubs PUT request for the specified path. After registering this, every PUT request to the path, will return
     the registered response.
     - parameter path: The path for the stubbed PUT request.
     - parameter response: An `AnyObject` that will be returned when a PUT request is made to the specified path.
     */
    public func stubPUT(path: String, response: AnyObject?, failed: Bool = false) {
        self.stub(.PUT, path: path, response: response, failed: failed)
    }

    /**
     Stubs PUT request to the specified path using the contents of a file. After registering this, every PUT request to the path, will return
     the contents of the registered file.
     - parameter path: The path for the stubbed PUT request.
     - parameter fileName: The name of the file, whose contents will be registered as a reponse.
     - parameter bundle: The NSBundle where the file is located.
     */
    public func stubPUT(path: String, fileName: String, bundle: NSBundle = NSBundle.mainBundle()) {
        self.stub(.PUT, path: path, fileName: fileName, bundle: bundle)
    }
}

// MARK: - DELETE
public extension Networking {
    /**
    DELETE request to the specified path, using the provided parameters.
    - parameter path: The path for the DELETE request.
    - parameter completion: A closure that gets called when the DELETE request is completed, it contains a `JSON` object and a `NSError`.
    */
    public func DELETE(path: String, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        self.request(.DELETE, path: path, contentType: .JSON, parameters: nil, completion: completion)
    }

    /**
     Cancels the DELETE request for the specified path. This causes the request to complete with error code -999
     - parameter path: The path for the cancelled DELETE request
     */
    public func cancelDELETE(path: String) {
        self.cancelRequest(.Data, requestType: .DELETE, path: path)
    }

    /**
     Stubs DELETE request for the specified path. After registering this, every DELETE request to the path, will return
     the registered response.
     - parameter path: The path for the stubbed DELETE request.
     - parameter response: An `AnyObject` that will be returned when a DELETE request is made to the specified path.
     */
    public func stubDELETE(path: String, response: AnyObject?, failed: Bool = false) {
        self.stub(.DELETE, path: path, response: response, failed: failed)
    }

    /**
     Stubs PUT request to the specified path using the contents of a file. After registering this, every DELETE request to the path, will return
     the contents of the registered file.
     - parameter path: The path for the stubbed DELETE request.
     - parameter fileName: The name of the file, whose contents will be registered as a reponse.
     - parameter bundle: The NSBundle where the file is located.
     */
    public func stubDELETE(path: String, fileName: String, bundle: NSBundle = NSBundle.mainBundle()) {
        self.stub(.DELETE, path: path, fileName: fileName, bundle: bundle)
    }
}
