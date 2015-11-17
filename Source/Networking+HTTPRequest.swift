import Foundation

public extension Networking {
    // MARK: GET

    /**
    GET request to the specified path.
    - parameter path: The path for the GET request.
    - parameter completion: A closure that gets called when the GET request is completed, it contains a `JSON` object and a `NSError`.
    */
    public func GET(path: String, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        self.request(.GET, path: path, parameters: nil, completion: completion)
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
    public func stubGET(path: String, response: AnyObject) {
        self.stub(.GET, path: path, response: response)
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

    // MARK: - POST

    /**
    POST request to the specified path, using the provided parameters.
    - parameter path: The path for the GET request.
    - parameter parameters: The parameters to be used, they will be serialized using NSJSONSerialization.
    - parameter completion: A closure that gets called when the POST request is completed, it contains a `JSON` object and a `NSError`.
    */
    public func POST(path: String, parameters: AnyObject?, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        self.request(.POST, path: path, parameters: parameters, completion: completion)
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
    public func stubPOST(path: String, response: AnyObject) {
        self.stub(.POST, path: path, response: response)
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
