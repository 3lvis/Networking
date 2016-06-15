import Foundation

public extension Int {
    /**
     Categorizes a status code.
     - returns: The NetworkingStatusCodeType of the status code.
     */
    public func statusCodeType() -> Networking.StatusCodeType {
        if self >= 100 && self < 200 {
            return .informational
        } else if self >= 200 && self < 300 {
            return .successful
        } else if self >= 300 && self < 400 {
            return .redirection
        } else if self >= 400 && self < 500 {
            return .clientError
        } else if self >= 500 && self < 600 {
            return .serverError
        } else {
            return .unknown
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
        case json
        case formURLEncoded
        case custom(String)
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
        case informational, successful, redirection, clientError, serverError, unknown
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
        case `default`, ephemeral, background
    }

    private let baseURL: String
    var fakeRequests = [RequestType : [String : FakeRequest]]()
    var token: String?
    var customAuthorizationHeader: String?
    var cache: Cache<AnyObject, AnyObject>
    var configurationType: ConfigurationType

    /**
     Flag used to disable synchronous request when running automatic tests
     */
    var disableTestingMode = false

    lazy var session: URLSession = {
        return URLSession(configuration: self.sessionConfiguration())
    }()

    /**
     Base initializer, it creates an instance of `Networking`.
     - parameter baseURL: The base URL for HTTP requests under `Networking`.
     */
    public init(baseURL: String, configurationType: ConfigurationType = .default, cache: Cache<AnyObject, AnyObject>? = nil) {
        self.baseURL = baseURL
        self.configurationType = configurationType
        self.cache = cache ?? Cache()
    }

    /**
     Authenticates using Basic Authentication, it converts username:password to Base64 then sets the
     Authorization header to "Basic \(Base64(username:password))"
     - parameter username: The username to be used
     - parameter password: The password to be used
     */
    public func authenticate(username: String, password: String) {
        let credentialsString = "\(username):\(password)"
        if let credentialsData = credentialsString.data(using: String.Encoding.utf8) {
            let base64Credentials = credentialsData.base64EncodedString([])
            let authString = "Basic \(base64Credentials)"

            let config  = self.sessionConfiguration()
            config.httpAdditionalHeaders = ["Authorization" : authString]

            self.session = URLSession(configuration: config)
        }
    }

    /**
     Authenticates using a Bearer token, sets the Authorization header to "Bearer \(token)"
     - parameter token: The token to be used
     */
    public func authenticate(token: String) {
        self.token = token
    }

    /**
     Authenticates using a custom HTTP Authorization header
     - parameter authorizationHeader: The authorization header to be used
     */
    public func authenticate(authorizationHeader: String) {
        self.customAuthorizationHeader = authorizationHeader
    }

    /**
     Returns a NSURL by appending the provided path to the Networking's base URL.
     - parameter path: The path to be appended to the base URL.
     - returns: A NSURL generated after appending the path to the base URL.
     */
    public func urlForPath(_ path: String) -> URL {
        guard let encodedPath = path.encodeUTF8() else { fatalError("Couldn't encode path to UTF8: \(path)") }
        guard let url = URL(string: self.baseURL + encodedPath) else { fatalError("Couldn't create a url using baseURL: \(self.baseURL) and encodedPath: \(encodedPath)") }
        return url
    }

    /**
     Returns the NSURL used to store a resource for a certain path. Useful to find where a download image is located.
     - parameter path: The path used to download the resource.
     - returns: A NSURL where a resource has been stored.
     */
    public func destinationURL(_ path: String, cacheName: String? = nil) -> URL {
        if let cacheName = cacheName {
            let replacedPath = cacheName.replacingOccurrences(of: "/", with: "-")
            guard let url = URL(string: replacedPath) else { fatalError("Couldn't create a destination url using cacheName: \(replacedPath)") }
            guard let cachesURL = FileManager.default().urlsForDirectory(.cachesDirectory, inDomains: .userDomainMask).first else { fatalError("Couldn't normalize url") }
            let destinationURL = try! cachesURL.appendingPathComponent(url.absoluteString!)

            return destinationURL
        } else {
            let finalPath = self.urlForPath(path).absoluteString
            let replacedPath = finalPath?.replacingOccurrences(of: "/", with: "-")
            guard let url = URL(string: replacedPath!) else { fatalError("Couldn't create a url using replacedPath: \(replacedPath)") }
            guard let cachesURL = FileManager.default().urlsForDirectory(.cachesDirectory, inDomains: .userDomainMask).first else { fatalError("Couldn't normalize url") }
            let destinationURL = try! cachesURL.appendingPathComponent(url.absoluteString!)

            return destinationURL
        }
    }

    /**
     Splits a url in base url and relative path
     - parameter path: The full url to be splitted
     - returns: A base url and a relative path
     */
    public static func splitBaseURLAndRelativePath(_ path: String) -> (baseURL: String, relativePath: String) {
        guard let encodedPath = path.encodeUTF8() else { fatalError("Couldn't encode path to UTF8: \(path)") }
        guard let url = URL(string: encodedPath) else { fatalError("Path \(encodedPath) can't be converted to url") }
        guard let baseURLWithDash = URL(string: "/", relativeTo: url)?.absoluteURL?.absoluteString else { fatalError("Can't find absolute url of url: \(url)") }
        let index = baseURLWithDash.characters.index(baseURLWithDash.endIndex, offsetBy: -1)
        let baseURL = baseURLWithDash.substring(to: index)
        let relativePath = path.replacingOccurrences(of: baseURL, with: "")

        return (baseURL, relativePath)
    }

    /**
     Cancels all the current requests.
     - parameter completion: The completion block to be called when all the requests are cancelled
     */
    public func cancelAllRequests(_ completion: ((Void) -> Void)?) {
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

            DispatchQueue.main.async {
                completion?()
            }
        }
    }
}

extension Networking {
    func sessionConfiguration() -> URLSessionConfiguration {
        switch self.configurationType {
        case .default:
            return URLSessionConfiguration.default()
        case .ephemeral:
            return URLSessionConfiguration.ephemeral()
        case .background:
            return URLSessionConfiguration.background(withIdentifier: "NetworkingBackgroundConfiguration")
        }
    }

    func fake(_ requestType: RequestType, path: String, fileName: String, bundle: Bundle = Bundle.main()) {
        do {
            if let result = try JSON.from(fileName, bundle: bundle) {
                self.fake(requestType, path: path, response: result, statusCode: 200)
            }
        } catch ParsingError.notFound {
            fatalError("We couldn't find \(fileName), are you sure is there?")
        } catch {
            fatalError("Converting data to JSON failed")
        }
    }

    func fake(_ requestType: RequestType, path: String, response: AnyObject?, statusCode: Int) {
        var fakeRequests = self.fakeRequests[requestType] ?? [String : FakeRequest]()
        fakeRequests[path] = FakeRequest(response: response, statusCode: statusCode)
        self.fakeRequests[requestType] = fakeRequests
    }

    func request(_ requestType: RequestType, path: String, contentType: ContentType, parameters: AnyObject?, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        if let responses = self.fakeRequests[requestType], fakeRequest = responses[path] {
            if fakeRequest.statusCode.statusCodeType() == .successful {
                completion(JSON: fakeRequest.response, error: nil)
            } else {
                let error = NSError(domain: Networking.ErrorDomain, code: fakeRequest.statusCode, userInfo: [NSLocalizedDescriptionKey : HTTPURLResponse.localizedString(forStatusCode: fakeRequest.statusCode)])
                completion(JSON: nil, error: error)
            }
        } else {
            let request = NSMutableURLRequest(url: self.urlForPath(path))
            request.httpMethod = requestType.rawValue
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
                case .json:
                    do {
                        request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
                    } catch let error as NSError {
                        serializingError = error
                    }
                    break
                case .formURLEncoded:
                    guard let parametersDictionary = parameters as? [String : AnyObject] else { fatalError("Couldn't cast parameters as dictionary: \(parameters)") }
                    let formattedParameters = parametersDictionary.formURLEncodedFormat()
                    request.httpBody = formattedParameters.data(using: String.Encoding.utf8)
                    break
                case .custom(_):
                    request.httpBody = parameters as? Data
                    break
                }
            }

            if let serializingError = serializingError {
                DispatchQueue.main.async {
                    completion(JSON: nil, error: serializingError)
                }
            } else {
                var connectionError: NSError?
                var result: AnyObject?
                let semaphore = DispatchSemaphore(value: 0)
                var returnedResponse: URLResponse?
                var returnedData: Data?

                self.session.dataTask(with: request as URLRequest) { data, response, error in
                    returnedResponse = response
                    connectionError = error
                    returnedData = data

                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                            do {
                                if let data = data where data.count > 0 {
                                    result = try JSONSerialization.jsonObject(with: data, options: [])
                                }
                            } catch let serializingError as NSError {
                                if error == nil {
                                    connectionError = serializingError
                                }
                            }
                        } else {
                            connectionError = NSError(domain: Networking.ErrorDomain, code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey : HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)])
                        }
                    }

                    if TestCheck.isTesting && self.disableTestingMode == false {
                        semaphore.signal()
                    } else {
                        DispatchQueue.main.async {
                            NetworkActivityIndicator.sharedIndicator.visible = false

                            self.logError(contentType, parameters: parameters, data: returnedData, request: request as URLRequest, response: returnedResponse, error: connectionError)
                            completion(JSON: result, error: connectionError)
                        }
                    }
                }.resume()

                if TestCheck.isTesting && self.disableTestingMode == false {
                    semaphore.wait(timeout: DispatchTime.distantFuture)
                    self.logError(contentType, parameters: parameters, data: returnedData, request: request as URLRequest, response: returnedResponse, error: connectionError)
                    completion(JSON: result, error: connectionError)
                }
            }
        }
    }

    class func valueForContentType(_ contentType: ContentType) -> String {
        switch contentType {
        case .json:
            return "application/json"
        case .formURLEncoded:
            return "application/x-www-form-urlencoded"
        case .custom(let value):
            return value
        }
    }

    func cancelRequest(_ sessionTaskType: SessionTaskType, requestType: RequestType, url: URL) {
        self.session.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            var sessionTasks = [URLSessionTask]()
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
                if sessionTask.originalRequest?.httpMethod == requestType.rawValue && sessionTask.originalRequest?.url?.absoluteString == url.absoluteString {
                    sessionTask.cancel()
                }
            }
        }
    }

    func logError(_ contentType: ContentType, parameters: AnyObject? = nil, data: Data?, request: URLRequest?, response: URLResponse?, error: NSError?) {
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
                case .json:
                    do {
                        let data = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
                        let string = String(data: data, encoding: String.Encoding.utf8)
                        print("Parameters: \(string)")
                        print(" ")
                    } catch let error as NSError {
                        print("Failed pretty printing parameters: \(parameters), error: \(error)")
                        print(" ")
                    }
                    break
                case .formURLEncoded:
                    guard let parametersDictionary = parameters as? [String : AnyObject] else { fatalError("Couldn't cast parameters as dictionary: \(parameters)") }
                    let formattedParameters = parametersDictionary.formURLEncodedFormat()
                    print("Parameters: \(formattedParameters)")
                    print(" ")
                    break
                default: break
                }

                print(" ")
            }

            if let data = data, stringData = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                print("Data: \(stringData)")
                print(" ")
            }

            if let response = response as? HTTPURLResponse {
                if let headers = request?.allHTTPHeaderFields {
                    print("Headers: \(headers)")
                    print(" ")
                }
                print("Response status code: \(response.statusCode) — \(HTTPURLResponse.localizedString(forStatusCode: response.statusCode))")
                print(" ")
                print("Path: \(response.url!.absoluteString)")
                print(" ")
                print("Response: \(response)")
                print(" ")
            }
        }
        print("================= ~ ==================")
        print(" ")
    }
}
