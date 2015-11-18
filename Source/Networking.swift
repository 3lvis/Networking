import Foundation
import TestCheck
import JSON
import NetworkActivityIndicator

public class Networking {
    internal enum RequestType: String {
        case GET, POST, PUT, DELETE
    }

    internal enum SessionTaskType: String {
        case Data, Upload, Download
    }

    private let baseURL: String
    internal var stubs: [RequestType : [String : AnyObject]]
    internal var token: String?
    internal var imageCache = NSCache()

    /**
     Internal flag used to disable synchronous request when running automatic tests
     */
    internal var disableTestingMode = false

    internal lazy var session: NSURLSession = {
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()

        return NSURLSession(configuration: config)
    }()

    /**
     Base initializer, it creates an instance of `Networking`.
     - parameter baseURL: The base URL for HTTP requests under `Networking`.
     */
    public init(baseURL: String) {
        self.baseURL = baseURL
        self.stubs = [RequestType : [String : AnyObject]]()
    }

    /**
     Authenticates using Basic Authentication, it converts username:password to Base64 then sets the
     Authorization header to "Basic \(Base64(username:password))"
     - parameter username: The username to be used
     - parameter password: The password to be used
     */
    public func authenticate(username: String, password: String) {
        let credentialsString = "\(username):\(password)"
        if let credentialsData = credentialsString.dataUsingEncoding(NSUTF8StringEncoding) {
            let base64Credentials = credentialsData.base64EncodedStringWithOptions([])
            let authString = "Basic \(base64Credentials)"

            let config  = NSURLSessionConfiguration.defaultSessionConfiguration()
            config.HTTPAdditionalHeaders = ["Authorization" : authString]

            self.session = NSURLSession(configuration: config)
        }
    }

    /**
     Authenticates using a token, sets the Authorization header to "Bearer \(token)"
     - parameter token: The token to be used
     */
    public func authenticate(token: String) {
        self.token = token
    }

    /**
    Returns a NSURL by appending the provided path to the Networking's base URL.
    - parameter path: The path to be appended to the base URL.
    - returns: A NSURL generated after appending the path to the base URL.
    */
    public func urlForPath(path: String) -> NSURL {
        return NSURL(string: self.baseURL + path)!
    }

    /**
     Returns the NSURL used to store a resource for a certain path. Useful to find where a download image is located.
     - parameter path: The path used to download the resource.
     - returns: A NSURL where a resource has been stored.
     */
    public func destinationURL(path: String) -> NSURL {
        guard let url = NSURL(string: (self.urlForPath(path).absoluteString as NSString).stringByReplacingOccurrencesOfString("/", withString: "-")),
            cachesURL = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask).first else { fatalError("Couldn't normalize url") }
        let destinationURL = cachesURL.URLByAppendingPathComponent(url.absoluteString)

        return destinationURL
    }
}

// MARK: - Private

extension Networking {
    internal func stub(requestType: RequestType, path: String, fileName: String, bundle: NSBundle = NSBundle.mainBundle()) {
        do {
            if let result = try JSON.from(fileName, bundle: bundle) {
                self.stub(requestType, path: path, response: result)
            }
        } catch ParsingError.NotFound {
            fatalError("We couldn't find \(fileName), are you sure is there?")
        } catch {
            fatalError("Converting data to JSON failed")
        }
    }

    internal func stub(requestType: RequestType, path: String, response: AnyObject) {
        var getStubs = self.stubs[requestType] ?? [String : AnyObject]()
        getStubs[path] = response
        self.stubs[requestType] = getStubs
    }

    internal func request(requestType: RequestType, path: String, parameters: AnyObject?, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        if let responses = self.stubs[requestType], response = responses[path] {
            completion(JSON: response, error: nil)
        } else {
            let request = NSMutableURLRequest(URL: self.urlForPath(path))
            request.HTTPMethod = requestType.rawValue
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")

            if let token = token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            NetworkActivityIndicator.sharedIndicator.visible = true

            var serializingError: NSError?
            if let parameters = parameters {
                do {
                    request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(parameters, options: [])
                } catch let error as NSError {
                    serializingError = error
                }
            }

            if let serializingError = serializingError {
                dispatch_async(dispatch_get_main_queue(), {
                    completion(JSON: nil, error: serializingError)
                })
            } else {
                var connectionError: NSError?
                var result: AnyObject?
                let semaphore = dispatch_semaphore_create(0)
                var returnedResponse: NSURLResponse?
                var returnedData: NSData?

                self.session.dataTaskWithRequest(request, completionHandler: { data, response, error in
                    returnedResponse = response
                    connectionError = error
                    returnedData = data

                    if let data = data {
                        do {
                            result = try NSJSONSerialization.JSONObjectWithData(data, options: .MutableLeaves)
                        } catch let serializingError as NSError {
                            if error == nil {
                                connectionError = serializingError
                            }
                        }
                    }

                    if TestCheck.isTesting && self.disableTestingMode == false {
                        dispatch_semaphore_signal(semaphore)
                    } else {
                        dispatch_async(dispatch_get_main_queue(), {
                            NetworkActivityIndicator.sharedIndicator.visible = false

                            self.logError(parameters, data: returnedData, request: request, response: returnedResponse, error: connectionError)
                            completion(JSON: result, error: connectionError)
                        })
                    }
                }).resume()

                if TestCheck.isTesting && self.disableTestingMode == false {
                    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
                    self.logError(parameters, data: returnedData, request: request, response: returnedResponse, error: connectionError)
                    completion(JSON: result, error: connectionError)
                }
            }
        }
    }

    internal func cancelRequest(sessionTaskType: SessionTaskType, requestType: RequestType, path: String) {
        let fullPath = self.urlForPath(path)

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
                if sessionTask.originalRequest?.HTTPMethod == requestType.rawValue && sessionTask.originalRequest?.URL?.absoluteString == fullPath.absoluteString {
                    sessionTask.cancel()
                }
            }
        }
    }

    internal func logError(parameters: AnyObject? = nil, data: NSData?, request: NSURLRequest?, response: NSURLResponse?, error: NSError?) {
        guard let error = error else { return }

        print(" ")
        print("========== Networking Error ==========")
        print(" ")

        print("Error \(error.code): \(error.description)")
        print(" ")

        if let request = request {
            print("Request: \(request)")
            print(" ")
        }

        if let parameters = parameters {
            print("parameters: \(parameters)")
            print(" ")
        }

        if let data = data, stringData = NSString(data: data, encoding: NSUTF8StringEncoding) {
            print("Data: \(stringData)")
            print(" ")
        }

        if let response = response as? NSHTTPURLResponse {
            print("Response status code: \(response.statusCode)")
            print(" ")
            print("Path: \(response.URL!.absoluteString)")
            print(" ")
            print("Response: \(response)")
            print(" ")
        }

        print("================= ~ ==================")
        print(" ")
    }
}
