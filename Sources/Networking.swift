import Foundation

public extension Int {
    /**
     Categorizes a status code.
     - returns: The NetworkingStatusCodeType of the status code.
     */
    public func statusCodeType() -> Networking.StatusCodeType {
        if self >= 100 && self < 200 {
            return .Informational
        } else if self >= 200 && self < 300 {
            return .Successful
        } else if self >= 300 && self < 400 {
            return .Redirection
        } else if self >= 400 && self < 500 {
            return .ClientError
        } else if self >= 500 && self < 600 {
            return .ServerError
        } else {
            return .Unknown
        }
    }
}

public class Networking {
    static let ErrorDomain = "NetworkingErrorDomain"

    struct FakeRequest {
        let response: AnyObject?
        let statusCode: Int
    }

    /**
     Provides the options for configuring your Networking object with NSURLSessionConfiguration.
     - `Default:` This configuration type manages upload and download tasks using the default options.
     - `Ephemeral:` A configuration type that uses no persistent storage for caches, cookies, or credentials. It's optimized for transferring data to and from your app’s memory.
     - `Background:` A configuration type that allows HTTP and HTTPS uploads or downloads to be performed in the background. It causes upload and download tasks to be performed by the system in a separate process.
     */
    public enum ConfigurationType {
        case Default, Ephemeral, Background
    }

    enum RequestType: String {
        case GET, POST, PUT, DELETE
    }

    enum SessionTaskType: String {
        case Data, Upload, Download
    }

    /**
     Sets the rules to serialize your parameters, also sets the `Content-Type` header.
     - `JSON:` Serializes your parameters using `NSJSONSerialization` and sets your `Content-Type` to `application/json`.
     - `FormURLEncoded:` Serializes your parameters using `Percent-encoding` and sets your `Content-Type` to `application/x-www-form-urlencoded`.
     - `MultipartFormData:` Serializes your parameters and parts as multipart and sets your `Content-Type` to `multipart/form-data`.
     - `Custom(String):` Sends your parameters as plain data, sets your `Content-Type` to the value inside `Custom`.
     */
    public enum ParameterType {
        /**
         Serializes your parameters using `NSJSONSerialization` and sets your `Content-Type` to `application/json`.
         */
        case JSON
        /**
         Serializes your parameters using `Percent-encoding` and sets your `Content-Type` to `application/x-www-form-urlencoded`.
         */
        case FormURLEncoded
        /**
         Serializes your parameters and parts as multipart and sets your `Content-Type` to `multipart/form-data`.
         */
        case MultipartFormData
        /**
         Sends your parameters as plain data, sets your `Content-Type` to the value inside `Custom`.
         */
        case Custom(String)

        func contentType(boundary boundary: String) -> String {
            switch self {
            case .JSON:
                return "application/json"
            case .FormURLEncoded:
                return "application/x-www-form-urlencoded"
            case .MultipartFormData:
                return "multipart/form-data; boundary=\(boundary)"
            case .Custom(let value):
                return value
            }
        }
    }

    enum ResponseType {
        case JSON
        case Data
        case Image

        var accept: String? {
            switch self {
            case .JSON:
                return "application/json"
            default:
                return nil
            }
        }
    }

    /**
     Categorizes a status code.
     - `Informational`: This class of status code indicates a provisional response, consisting only of the Status-Line and optional headers, and is terminated by an empty line.
     - `Successful`: This class of status code indicates that the client's request was successfully received, understood, and accepted.
     - `Redirection`: This class of status code indicates that further action needs to be taken by the user agent in order to fulfill the request.
     - `ClientError:` The 4xx class of status code is intended for cases in which the client seems to have erred.
     - `ServerError:` Response status codes beginning with the digit "5" indicate cases in which the server is aware that it has erred or is incapable of performing the request.
     - `Unknown:` This response status code could be used by Foundation for other types of states, for example when a request gets cancelled you will receive status code -999.
     */
    public enum StatusCodeType {
        case Informational, Successful, Redirection, ClientError, ServerError, Unknown
    }

    private let baseURL: String
    var fakeRequests = [RequestType : [String : FakeRequest]]()
    var token: String?
    var authorizationHeaderValue: String?
    var authorizationHeaderKey = "Authorization"
    var cache: NSCache
    var configurationType: ConfigurationType

    /**
     Flag used to disable synchronous request when running automatic tests.
     */
    var disableTestingMode = false

    /**
     The boundary used for multipart requests.
     */
    let boundary = String(format: "net.3lvis.networking.%08x%08x", arc4random(), arc4random())

    lazy var session: NSURLSession = {
        return NSURLSession(configuration: self.sessionConfiguration())
    }()

    /**
     Base initializer, it creates an instance of `Networking`.
     - parameter baseURL: The base URL for HTTP requests under `Networking`.
     */
    public init(baseURL: String, configurationType: ConfigurationType = .Default, cache: NSCache? = nil) {
        self.baseURL = baseURL
        self.configurationType = configurationType
        self.cache = cache ?? NSCache()
    }

    /**
     Authenticates using Basic Authentication, it converts username:password to Base64 then sets the Authorization header to "Basic \(Base64(username:password))".
     - parameter username: The username to be used.
     - parameter password: The password to be used.
     */
    public func authenticate(username username: String, password: String) {
        let credentialsString = "\(username):\(password)"
        if let credentialsData = credentialsString.dataUsingEncoding(NSUTF8StringEncoding) {
            let base64Credentials = credentialsData.base64EncodedStringWithOptions([])
            let authString = "Basic \(base64Credentials)"

            let config  = self.sessionConfiguration()
            config.HTTPAdditionalHeaders = [self.authorizationHeaderKey : authString]

            self.session = NSURLSession(configuration: config)
        }
    }

    /**
     Authenticates using a Bearer token, sets the Authorization header to "Bearer \(token)".
     - parameter token: The token to be used.
     */
    public func authenticate(token token: String) {
        self.token = token
    }

    /**
     Authenticates using a custom HTTP Authorization header.
     - parameter authorizationHeaderKey: Sets this value as the key for the HTTP `Authorization` header
     - parameter authorizationHeaderValue: Sets this value to the HTTP `Authorization` header or to the `headerKey` if you provided that.
     */
    public func authenticate(headerKey headerKey: String = "Authorization", headerValue: String) {
        self.authorizationHeaderKey = headerKey
        self.authorizationHeaderValue = headerValue
    }

    /**
     Returns a NSURL by appending the provided path to the Networking's base URL.
     - parameter path: The path to be appended to the base URL.
     - returns: A NSURL generated after appending the path to the base URL.
     */
    public func urlForPath(path: String) -> NSURL {
        guard let encodedPath = path.encodeUTF8() else { fatalError("Couldn't encode path to UTF8: \(path)") }
        guard let url = NSURL(string: self.baseURL + encodedPath) else { fatalError("Couldn't create a url using baseURL: \(self.baseURL) and encodedPath: \(encodedPath)") }
        return url
    }

    /**
     Returns the NSURL used to store a resource for a certain path. Useful to find where a download image is located.
     - parameter path: The path used to download the resource.
     - returns: A NSURL where a resource has been stored.
     */
    public func destinationURL(path: String, cacheName: String? = nil) throws -> NSURL {
        #if os(tvOS)
            let directory = NSSearchPathDirectory.CachesDirectory
        #else
            let directory = TestCheck.isTesting ? NSSearchPathDirectory.CachesDirectory : NSSearchPathDirectory.DocumentDirectory
        #endif
        let finalPath = cacheName ?? self.urlForPath(path).absoluteString
        #if swift(>=2.3)
            let replacedPath = finalPath!.stringByReplacingOccurrencesOfString("/", withString: "-")
        #else
            let replacedPath = finalPath.stringByReplacingOccurrencesOfString("/", withString: "-")
        #endif
        if let url = NSURL(string: replacedPath) {
            if let cachesURL = NSFileManager.defaultManager().URLsForDirectory(directory, inDomains: .UserDomainMask).first {
                #if !os(tvOS)
                    try cachesURL.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey)
                #endif

                #if swift(>=2.3)
                    let destinationURL = cachesURL.URLByAppendingPathComponent(url.absoluteString!)
                    return destinationURL!
                #else
                    let destinationURL = cachesURL.URLByAppendingPathComponent(url.absoluteString)
                    return destinationURL
                #endif
            } else {
                throw NSError(domain: Networking.ErrorDomain, code: 9999, userInfo: [NSLocalizedDescriptionKey : "Couldn't normalize url"])
            }
        } else {
            throw NSError(domain: Networking.ErrorDomain, code: 9999, userInfo: [NSLocalizedDescriptionKey : "Couldn't create a url using replacedPath: \(replacedPath)"])
        }
    }

    /**
     Splits a url in base url and relative path.
     - parameter path: The full url to be splitted.
     - returns: A base url and a relative path.
     */
    public static func splitBaseURLAndRelativePath(path: String) -> (baseURL: String, relativePath: String) {
        guard let encodedPath = path.encodeUTF8() else { fatalError("Couldn't encode path to UTF8: \(path)") }
        guard let url = NSURL(string: encodedPath) else { fatalError("Path \(encodedPath) can't be converted to url") }
        #if swift(>=2.3)
            guard let baseURLWithDash = NSURL(string: "/", relativeToURL: url)?.absoluteURL!.absoluteString else { fatalError("Can't find absolute url of url: \(url)") }
        #else
            guard let baseURLWithDash = NSURL(string: "/", relativeToURL: url)?.absoluteURL.absoluteString else { fatalError("Can't find absolute url of url: \(url)") }
        #endif
        let index = baseURLWithDash.endIndex.advancedBy(-1)
        let baseURL = baseURLWithDash.substringToIndex(index)
        let relativePath = path.stringByReplacingOccurrencesOfString(baseURL, withString: "")

        return (baseURL, relativePath)
    }

    /**
     Cancels the request that matches the requestID.
     - parameter requestID: The ID of the request to be cancelled.
     - parameter completion: The completion block to be called when the request is cancelled.
     */
    func cancel(requestID: String, completion: (Void -> Void)? = nil) {
        self.session.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            var tasks = [NSURLSessionTask]()
            tasks.appendContentsOf(dataTasks as [NSURLSessionTask])
            tasks.appendContentsOf(uploadTasks as [NSURLSessionTask])
            tasks.appendContentsOf(downloadTasks as [NSURLSessionTask])

            for task in tasks {
                if task.taskDescription == requestID {
                    task.cancel()
                    break
                }
            }

            completion?()
        }
    }

    /**
     Cancels all the current requests.
     - parameter completion: The completion block to be called when all the requests are cancelled.
     */
    public func cancelAllRequests(completion: (Void -> Void)?) {
        self.session.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            for sessionTask in dataTasks {
                sessionTask.cancel()
            }
            for sessionTask in downloadTasks {
                sessionTask.cancel()
            }
            for sessionTask in uploadTasks {
                sessionTask.cancel()
            }

            TestCheck.testBlock(disabled: self.disableTestingMode) {
                completion?()
            }
        }
    }

    /**
     Downloads data from a URL, caching the result.
     - parameter path: The path used to download the resource.
     - parameter completion: A closure that gets called when the download request is completed, it contains  a `data` object and a `NSError`.
     */
    public func downloadData(path: String, cacheName: String? = nil, completion: (data: NSData?, error: NSError?) -> Void) {
        self.request(.GET, path: path, cacheName: cacheName, parameterType: nil, parameters: nil, parts: nil, responseType: .Data) { response, headers, error in
            completion(data: response as? NSData, error: error)
        }
    }

    /**
     Retrieves data from the cache or from the filesystem.
     - parameter path: The path where the image is located.
     - parameter cacheName: The cache name used to identify the downloaded data, by default the path is used.
     - parameter completion: A closure that returns the data from the cache, if no data is found it will return nil.
     */
    public func dataFromCache(path: String, cacheName: String? = nil) -> NSData? {
        let object = self.objectFromCache(path, cacheName: cacheName, responseType: .Data)

        return object as? NSData
    }

    //*************************//
    //**** Deprecated area ****//
    //*************************//

    /**
     [Deprecated] Use `authenticate(headerValue)` instead.
     */
    @available(*, deprecated=1.1.0, message="Use `authenticate(headerValue)` instead") public func authenticate(authorizationHeader authorizationHeader: String) {
        self.authenticate(headerValue: authorizationHeader)
    }
}

extension Networking {
    func objectFromCache(path: String, cacheName: String? = nil, responseType: ResponseType) -> AnyObject? {
        guard let destinationURL = try? self.destinationURL(path, cacheName: cacheName) else { fatalError("Couldn't get destination URL for path: \(path) and cacheName: \(cacheName)") }

        #if swift(>=2.3)
            let key = destinationURL.absoluteString!
        #else
            let key = destinationURL.absoluteString
        #endif
        if let object = self.cache.objectForKey(key) {
            return object
        } else if NSFileManager.defaultManager().fileExistsAtURL(destinationURL) {
            var returnedObject: AnyObject?

                let object = self.dataForDestinationURL(destinationURL)
                if responseType == .Image {
                    returnedObject = NetworkingImage(data: object)
                } else {
                    returnedObject = object
                }
                if let returnedObject = returnedObject {
                    #if swift(>=2.3)
                        self.cache.setObject(returnedObject, forKey: destinationURL.absoluteString!)
                    #else
                        self.cache.setObject(returnedObject, forKey: destinationURL.absoluteString)
                    #endif
                }

                return returnedObject
        } else {
            return nil
        }
    }

    func dataForDestinationURL(url: NSURL) -> NSData {
        guard let path = url.path else { fatalError("Couldn't get path for url: \(url)") }
        guard let data = NSFileManager.defaultManager().contentsAtPath(path) else { fatalError("Couldn't get image in destination url: \(url)") }

        return data
    }

    func sessionConfiguration() -> NSURLSessionConfiguration {
        switch self.configurationType {
        case .Default:
            return NSURLSessionConfiguration.defaultSessionConfiguration()
        case .Ephemeral:
            return NSURLSessionConfiguration.ephemeralSessionConfiguration()
        case .Background:
            return NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("NetworkingBackgroundConfiguration")
        }
    }

    func fake(requestType: RequestType, path: String, fileName: String, bundle: NSBundle = NSBundle.mainBundle()) {
        do {
            if let result = try JSON.from(fileName, bundle: bundle) {
                self.fake(requestType, path: path, response: result, statusCode: 200)
            }
        } catch ParsingError.NotFound {
            fatalError("We couldn't find \(fileName), are you sure is there?")
        } catch {
            fatalError("Converting data to JSON failed")
        }
    }

    func fake(requestType: RequestType, path: String, response: AnyObject?, statusCode: Int) {
        var fakeRequests = self.fakeRequests[requestType] ?? [String : FakeRequest]()
        fakeRequests[path] = FakeRequest(response: response, statusCode: statusCode)
        self.fakeRequests[requestType] = fakeRequests
    }

    func request(requestType: RequestType, path: String, cacheName: String? = nil, parameterType: ParameterType?, parameters: AnyObject?, parts: [FormDataPart]?, responseType: ResponseType, completion: (response: AnyObject?, headers: [String : AnyObject], error: NSError?) -> ()) -> String {
        var requestID = NSUUID().UUIDString

        if let responses = self.fakeRequests[requestType], fakeRequest = responses[path] {
            if fakeRequest.statusCode.statusCodeType() == .Successful {
                completion(response: fakeRequest.response, headers: [String : AnyObject](), error: nil)
            } else {
                let error = NSError(domain: Networking.ErrorDomain, code: fakeRequest.statusCode, userInfo: [NSLocalizedDescriptionKey : NSHTTPURLResponse.localizedStringForStatusCode(fakeRequest.statusCode)])
                completion(response: fakeRequest.response, headers: [String : AnyObject](), error: error)
            }
        } else {
            switch responseType {
            case .JSON:
                requestID = self.dataRequest(requestType, path: path, cacheName: cacheName, parameterType: parameterType, parameters: parameters, parts: parts, responseType: responseType) { data, headers, error in
                    var returnedError = error
                    var returnedResponse: AnyObject?
                    if let data = data where data.length > 0 {
                        do {
                            returnedResponse = try NSJSONSerialization.JSONObjectWithData(data, options: [])
                        } catch let JSONError as NSError {
                            if error == nil {
                                returnedError = JSONError
                            }
                        }
                    }

                    TestCheck.testBlock(disabled: self.disableTestingMode) {
                        completion(response: returnedResponse, headers: headers, error: returnedError)
                    }
                }
            case .Data, .Image:
                let object = self.objectFromCache(path, cacheName: cacheName, responseType: responseType)
                if let object = object {
                    TestCheck.testBlock(disabled: self.disableTestingMode) {
                        completion(response: object, headers: [String : AnyObject](), error: nil)
                    }
                } else {
                    self.dataRequest(requestType, path: path, cacheName: cacheName, parameterType: parameterType, parameters: parameters, parts: parts, responseType: responseType) { data, headers, error in
                        var returnedResponse: AnyObject?
                        if let data = data where data.length > 0 {
                            guard let destinationURL = try? self.destinationURL(path, cacheName: cacheName) else { fatalError("Couldn't get destination URL for path: \(path) and cacheName: \(cacheName)") }
                            data.writeToURL(destinationURL, atomically: true)
                            switch responseType {
                            case .Data:
                                #if swift(>=2.3)
                                    self.cache.setObject(data, forKey: destinationURL.absoluteString!)
                                #else
                                    self.cache.setObject(data, forKey: destinationURL.absoluteString)
                                #endif
                                returnedResponse = data
                                break
                            case .Image:
                                if let image = NetworkingImage(data: data) {
                                    #if swift(>=2.3)
                                        self.cache.setObject(image, forKey: destinationURL.absoluteString!)
                                    #else
                                        self.cache.setObject(image, forKey: destinationURL.absoluteString)
                                    #endif
                                    returnedResponse = image
                                }
                                break
                            default:
                                fatalError("Response Type is different than Data and Image")
                                break
                            }
                        }
                        TestCheck.testBlock(disabled: self.disableTestingMode) {
                            completion(response: returnedResponse, headers: [String : AnyObject](), error: error)
                        }
                    }
                }
            }
        }

        return requestID
    }

    func dataRequest(requestType: RequestType, path: String, cacheName: String? = nil, parameterType: ParameterType?, parameters: AnyObject?, parts: [FormDataPart]?, responseType: ResponseType, completion: (response: NSData?, headers: [String : AnyObject], error: NSError?) -> ()) -> String {
        let requestID = NSUUID().UUIDString
        let request = NSMutableURLRequest(URL: self.urlForPath(path))
        request.HTTPMethod = requestType.rawValue

        if let parameterType = parameterType {
            request.addValue(parameterType.contentType(boundary: self.boundary), forHTTPHeaderField: "Content-Type")
        }

        if let accept = responseType.accept {
            request.addValue(accept, forHTTPHeaderField: "Accept")
        }

        if let authorizationHeader = self.authorizationHeaderValue {
            request.setValue(authorizationHeader, forHTTPHeaderField: self.authorizationHeaderKey)
        } else if let token = self.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: self.authorizationHeaderKey)
        }

        dispatch_async(dispatch_get_main_queue()) {
            NetworkActivityIndicator.sharedIndicator.visible = true
        }

        var serializingError: NSError?
        if let parameterType = parameterType, parameters = parameters {
            switch parameterType {
            case .JSON:
                do {
                    request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(parameters, options: [])
                } catch let error as NSError {
                    serializingError = error
                }
                break
            case .FormURLEncoded:
                guard let parametersDictionary = parameters as? [String : AnyObject] else { fatalError("Couldn't convert parameters to a dictionary: \(parameters)") }
                let formattedParameters = parametersDictionary.formURLEncodedFormat()
                request.HTTPBody = formattedParameters.dataUsingEncoding(NSUTF8StringEncoding)
                break
            case .MultipartFormData:
                let bodyData = NSMutableData()

                if let parameters = parameters as? [String : AnyObject] {
                    for (key, value) in parameters {
                        let usedValue: AnyObject = value is NSNull ? "null" : value
                        var body = ""
                        body += "--\(self.boundary)\r\n"
                        body += "Content-Disposition: form-data; name=\"\(key)\""
                        body += "\r\n\r\n\(usedValue)\r\n"
                        bodyData.appendData(body.dataUsingEncoding(NSUTF8StringEncoding)!)
                    }
                }

                if let parts = parts {
                    for var part in parts {
                        part.boundary = self.boundary
                        bodyData.appendData(part.formData)
                    }
                }

                bodyData.appendData("--\(self.boundary)--\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
                request.HTTPBody = bodyData
                break
            case .Custom(_):
                request.HTTPBody = parameters as? NSData
                break
            }
        }

        if let serializingError = serializingError {
            completion(response: nil, headers: [String : AnyObject](), error: serializingError)
        } else {
            var connectionError: NSError?
            let semaphore = dispatch_semaphore_create(0)
            var returnedResponse: NSURLResponse?
            var returnedData: NSData?
            var returnedHeaders = [String : AnyObject]()

            let session = self.session.dataTaskWithRequest(request) { data, response, error in
                returnedResponse = response
                connectionError = error
                returnedData = data

                if let httpResponse = response as? NSHTTPURLResponse {
                    if let headers = httpResponse.allHeaderFields as? [String : AnyObject] {
                        returnedHeaders = headers
                    }

                    if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                        if let data = data where data.length > 0 {
                            returnedData = data
                        }
                    } else {
                        connectionError = NSError(domain: Networking.ErrorDomain, code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey : NSHTTPURLResponse.localizedStringForStatusCode(httpResponse.statusCode)])
                    }
                }

                if TestCheck.isTesting && self.disableTestingMode == false {
                    dispatch_semaphore_signal(semaphore)
                } else {
                    dispatch_async(dispatch_get_main_queue()) {
                        NetworkActivityIndicator.sharedIndicator.visible = false
                    }

                    self.logError(parameterType: parameterType, parameters: parameters, data: returnedData, request: request, response: returnedResponse, error: connectionError)
                    completion(response: returnedData, headers: returnedHeaders, error: connectionError)
                }
            }

            session.taskDescription = requestID
            session.resume()

            if TestCheck.isTesting && self.disableTestingMode == false {
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
                self.logError(parameterType: parameterType, parameters: parameters, data: returnedData, request: request, response: returnedResponse, error: connectionError)
                completion(response: returnedData, headers: returnedHeaders, error: connectionError)
            }
        }

        return requestID
    }

    func cancelRequest(sessionTaskType: SessionTaskType, requestType: RequestType, url: NSURL, completion: (Void -> Void)?) {
        self.session.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            var sessionTasks = [NSURLSessionTask]()
            switch sessionTaskType {
            case .Data:
                sessionTasks = dataTasks
                break
            case .Download:
                sessionTasks = downloadTasks
                break
            case .Upload:
                sessionTasks = uploadTasks
                break
            }

            for sessionTask in sessionTasks {
                if sessionTask.originalRequest?.HTTPMethod == requestType.rawValue && sessionTask.originalRequest?.URL?.absoluteString == url.absoluteString {
                    sessionTask.cancel()
                    break
                }
            }

            completion?()
        }
    }

    func logError(parameterType parameterType: ParameterType?, parameters: AnyObject? = nil, data: NSData?, request: NSURLRequest?, response: NSURLResponse?, error: NSError?) {
        guard let error = error else { return }

        print(" ")
        print("========== Networking Error ==========")
        print(" ")

        let isCancelled = error.code == -999
        if isCancelled {
            if let request = request, url = request.URL {
                print("Cancelled request: \(url.absoluteString)")
                print(" ")
            }
        } else {
            print("*** Request ***")
            print(" ")

            print("Error \(error.code): \(error.description)")
            print(" ")

            if let request = request, url = request.URL {
                print("URL: \(url.absoluteString)")
                print(" ")
            }

            if let headers = request?.allHTTPHeaderFields {
                print("Headers: \(headers)")
                print(" ")
            }

            if let parameterType = parameterType, parameters = parameters {
                switch parameterType {
                case .JSON:
                    do {
                        let data = try NSJSONSerialization.dataWithJSONObject(parameters, options: .PrettyPrinted)
                        let string = String(data: data, encoding: NSUTF8StringEncoding)
                        if let string = string {
                            print("Parameters: \(string)")
                            print(" ")
                        }
                    } catch let error as NSError {
                        print("Failed pretty printing parameters: \(parameters), error: \(error)")
                        print(" ")
                    }
                    break
                case .FormURLEncoded:
                    guard let parametersDictionary = parameters as? [String : AnyObject] else { fatalError("Couldn't cast parameters as dictionary: \(parameters)") }
                    let formattedParameters = parametersDictionary.formURLEncodedFormat()
                    print("Parameters: \(formattedParameters)")
                    print(" ")
                    break
                default: break
                }
            }

            if let data = data, stringData = String(data: data, encoding: NSUTF8StringEncoding) {
                print("Data: \(stringData)")
                print(" ")
            }

            if let response = response as? NSHTTPURLResponse {
                print("*** Response ***")
                print(" ")

                if let headers = response.allHeaderFields as? [String : AnyObject] {
                    print("Headers: \(headers)")
                    print(" ")
                }

                print("Status code: \(response.statusCode) — \(NSHTTPURLResponse.localizedStringForStatusCode(response.statusCode))")
                print(" ")
            }
        }
        print("================= ~ ==================")
        print(" ")
    }
}
