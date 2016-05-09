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

struct FakeRequest {
    let response: AnyObject?
    let statusCode: Int
}

public class Networking {
    static let ErrorDomain = "NetworkingErrorDomain"

    public enum ContentType {
        case JSON
        case FormURLEncoded
        case Custom(String)
    }

    /**
     Categorizes a status code.
     - `Informational`: This class of status code indicates a provisional response, consisting only of the Status-Line and optional headers, and is terminated by an empty line.
     - `Successful`: This class of status code indicates that the client's request was successfully received, understood, and accepted.
     - `Redirection`: This class of status code indicates that further action needs to be taken by the user agent in order to fulfill the request.
     - `ClientError:` The 4xx class of status code is intended for cases in which the client seems to have erred.
     - `ServerError:` Response status codes beginning with the digit "5" indicate cases in which the server is aware that it has erred or is incapable of performing the request.
     - `Unknown:` This response status code could be used by Foundation for other types of states, for example when a request gets cancelled you will receive status code -999
     */
    public enum StatusCodeType {
        case Informational, Successful, Redirection, ClientError, ServerError, Unknown
    }

    enum RequestType: String {
        case GET, POST, PUT, DELETE
    }

    enum SessionTaskType: String {
        case Data, Upload, Download
    }

    /**
     Provides the a bridge for configuring your Networking object with NSURLSessionConfiguration.
     - `Default:` This configuration type manages upload and download tasks using the default options.
     - `Ephemeral:` A configuration type that uses no persistent storage for caches, cookies, or credentials.
     It's optimized for transferring data to and from your app’s memory.
     - `Background:` A configuration type that allows HTTP and HTTPS uploads or downloads to be performed in the background.
     It causes upload and download tasks to be performed by the system in a separate process.
     */
    public enum ConfigurationType {
        case Default, Ephemeral, Background
    }

    private let baseURL: String
    var fakeRequests = [RequestType : [String : FakeRequest]]()
    var token: String?
    var customAuthorizationHeader: String?
    var cache: NSCache
    var configurationType: ConfigurationType

    /**
     Flag used to disable synchronous request when running automatic tests
     */
    var disableTestingMode = false

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
     Authenticates using Basic Authentication, it converts username:password to Base64 then sets the
     Authorization header to "Basic \(Base64(username:password))"
     - parameter username: The username to be used
     - parameter password: The password to be used
     */
    public func authenticate(username username: String, password: String) {
        let credentialsString = "\(username):\(password)"
        if let credentialsData = credentialsString.dataUsingEncoding(NSUTF8StringEncoding) {
            let base64Credentials = credentialsData.base64EncodedStringWithOptions([])
            let authString = "Basic \(base64Credentials)"

            let config  = self.sessionConfiguration()
            config.HTTPAdditionalHeaders = ["Authorization" : authString]

            self.session = NSURLSession(configuration: config)
        }
    }

    /**
     Authenticates using a Bearer token, sets the Authorization header to "Bearer \(token)"
     - parameter token: The token to be used
     */
    public func authenticate(token token: String) {
        self.token = token
    }

    /**
     Authenticates using a custom HTTP Authorization header
     - parameter authorizationHeader: The authorization header to be used
     */
    public func authenticate(authorizationHeader authorizationHeader: String) {
        self.customAuthorizationHeader = authorizationHeader
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
    public func destinationURL(path: String, cacheName: String? = nil) -> NSURL {
        if let cacheName = cacheName {
            let replacedPath = cacheName.stringByReplacingOccurrencesOfString("/", withString: "-")
            guard let url = NSURL(string: replacedPath) else { fatalError("Couldn't create a destination url using cacheName: \(replacedPath)") }
            guard let cachesURL = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask).first else { fatalError("Couldn't normalize url") }
            let destinationURL = cachesURL.URLByAppendingPathComponent(url.absoluteString)

            return destinationURL
        } else {
            let finalPath = self.urlForPath(path).absoluteString
            let replacedPath = finalPath.stringByReplacingOccurrencesOfString("/", withString: "-")
            guard let url = NSURL(string: replacedPath) else { fatalError("Couldn't create a url using replacedPath: \(replacedPath)") }
            guard let cachesURL = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask).first else { fatalError("Couldn't normalize url") }
            let destinationURL = cachesURL.URLByAppendingPathComponent(url.absoluteString)

            return destinationURL
        }
    }

    /**
     Splits a url in base url and relative path
     - parameter path: The full url to be splitted
     - returns: A base url and a relative path
     */
    public static func splitBaseURLAndRelativePath(path: String) -> (baseURL: String, relativePath: String) {
        guard let encodedPath = path.encodeUTF8() else { fatalError("Couldn't encode path to UTF8: \(path)") }
        guard let url = NSURL(string: encodedPath) else { fatalError("Path \(encodedPath) can't be converted to url") }
        guard let baseURLWithDash = NSURL(string: "/", relativeToURL: url)?.absoluteURL.absoluteString else { fatalError("Can't find absolute url of url: \(url)") }
        let index = baseURLWithDash.endIndex.advancedBy(-1)
        let baseURL = baseURLWithDash.substringToIndex(index)
        let relativePath = path.stringByReplacingOccurrencesOfString(baseURL, withString: "")

        return (baseURL, relativePath)
    }

    /**
     Cancels all the current requests.
     - parameter completion: The completion block to be called when all the requests are cancelled
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

            dispatch_async(dispatch_get_main_queue()) {
                completion?()
            }
        }
    }
    
    
    /**
     Downloads data from a URL, caching the result.
     - Careful: Doesn't create a new task if current task with same URL is already running.
     - parameter URL: the data URL.
     - parameter completion: the completion handler.
     */
    public func downloadData(URL: NSURL, completion: (data: NSData?, error: NSError?) -> ()) {
        if let task = self.cache.objectForKey(String(format: "task: ", URL.absoluteString)) {
//            NSLog("Task for this URL already processing")
        } else if let data = self.cache.objectForKey(URL.absoluteString) as? NSData {
//            NSLog("Cached data")
            self.cache.removeObjectForKey(String(format: "task: ", URL.absoluteString))
            completion(data: data, error: nil)
        } else {
//            NSLog("Fetche data")
            let task = self.session.dataTaskWithURL(URL) { (data, response, err) in
                if let data = data {
                    self.cache.setObject(data, forKey: URL.absoluteString)
                    self.cache.removeObjectForKey(String(format: "task: ", URL.absoluteString))
                    completion(data: data, error: err)
                }
            }
            self.cache.setObject(task, forKey: String(format: "task: ", URL.absoluteString))
            task.resume()
        }
    }
}

extension Networking {
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

    func request(requestType: RequestType, path: String, contentType: ContentType, parameters: AnyObject?, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        if let responses = self.fakeRequests[requestType], fakeRequest = responses[path] {
            if fakeRequest.statusCode.statusCodeType() == .Successful {
                completion(JSON: fakeRequest.response, error: nil)
            } else {
                let error = NSError(domain: Networking.ErrorDomain, code: fakeRequest.statusCode, userInfo: [NSLocalizedDescriptionKey : NSHTTPURLResponse.localizedStringForStatusCode(fakeRequest.statusCode)])
                completion(JSON: nil, error: error)
            }
        } else {
            let request = NSMutableURLRequest(URL: self.urlForPath(path))
            request.HTTPMethod = requestType.rawValue
            request.addValue(Networking.valueForContentType(contentType), forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")

            if let authorizationHeader = self.customAuthorizationHeader {
                request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
            } else if let token = self.token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            NetworkActivityIndicator.sharedIndicator.visible = true

            var serializingError: NSError?
            if let parameters = parameters {
                switch contentType {
                case .JSON:
                    do {
                        request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(parameters, options: [])
                    } catch let error as NSError {
                        serializingError = error
                    }
                    break
                case .FormURLEncoded:
                    guard let parametersDictionary = parameters as? [String : AnyObject] else { fatalError("Couldn't cast parameters as dictionary: \(parameters)") }
                    let formattedParameters = parametersDictionary.formURLEncodedFormat()
                    request.HTTPBody = formattedParameters.dataUsingEncoding(NSUTF8StringEncoding)
                    break
                case .Custom(_):
                    request.HTTPBody = parameters as? NSData
                    break
                }
            }

            if let serializingError = serializingError {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(JSON: nil, error: serializingError)
                }
            } else {
                var connectionError: NSError?
                var result: AnyObject?
                let semaphore = dispatch_semaphore_create(0)
                var returnedResponse: NSURLResponse?
                var returnedData: NSData?

                self.session.dataTaskWithRequest(request) { data, response, error in
                    returnedResponse = response
                    connectionError = error
                    returnedData = data

                    if let httpResponse = response as? NSHTTPURLResponse {
                        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                            do {
                                if let data = data where data.length > 0 {
                                    result = try NSJSONSerialization.JSONObjectWithData(data, options: [])
                                }
                            } catch let serializingError as NSError {
                                if error == nil {
                                    connectionError = serializingError
                                }
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

                            self.logError(contentType, parameters: parameters, data: returnedData, request: request, response: returnedResponse, error: connectionError)
                            completion(JSON: result, error: connectionError)
                        }
                    }
                }.resume()

                if TestCheck.isTesting && self.disableTestingMode == false {
                    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
                    self.logError(contentType, parameters: parameters, data: returnedData, request: request, response: returnedResponse, error: connectionError)
                    completion(JSON: result, error: connectionError)
                }
            }
        }
    }

    class func valueForContentType(contentType: ContentType) -> String {
        switch contentType {
        case .JSON:
            return "application/json"
        case .FormURLEncoded:
            return "application/x-www-form-urlencoded"
        case .Custom(let value):
            return value
        }
    }

    func cancelRequest(sessionTaskType: SessionTaskType, requestType: RequestType, url: NSURL) {
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
                }
            }
        }
    }

    func logError(contentType: ContentType, parameters: AnyObject? = nil, data: NSData?, request: NSURLRequest?, response: NSURLResponse?, error: NSError?) {
        guard let error = error else { return }

        print(" ")
        print("========== Networking Error ==========")
        print(" ")

        let isCancelled = error.code == -999
        if isCancelled {
            if let request = request {
                print("Cancelled request: \(request)")
                print(" ")
            }
        } else {
            print("Error \(error.code): \(error.description)")
            print(" ")

            if let request = request {
                print("Request: \(request)")
                print(" ")
            }

            if let parameters = parameters {
                switch contentType {
                case .JSON:
                    do {
                        let data = try NSJSONSerialization.dataWithJSONObject(parameters, options: .PrettyPrinted)
                        let string = String(data: data, encoding: NSUTF8StringEncoding)
                        print("Parameters: \(string)")
                        print(" ")
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

                print(" ")
            }

            if let data = data, stringData = NSString(data: data, encoding: NSUTF8StringEncoding) {
                print("Data: \(stringData)")
                print(" ")
            }

            if let response = response as? NSHTTPURLResponse {
                if let headers = request?.allHTTPHeaderFields {
                    print("Headers: \(headers)")
                    print(" ")
                }
                print("Response status code: \(response.statusCode) — \(NSHTTPURLResponse.localizedStringForStatusCode(response.statusCode))")
                print(" ")
                print("Path: \(response.URL!.absoluteString)")
                print(" ")
                print("Response: \(response)")
                print(" ")
            }
        }
        print("================= ~ ==================")
        print(" ")
    }
}
