import Foundation
import TestCheck
import JSON

#if os(iOS) || os(tvOS) || os(watchOS)
    import UIKit
#endif

public class Networking {
    private enum RequestType: String {
        case GET, POST
    }

    private enum SessionTaskType: String {
        case Data, Upload, Download
    }

    private let baseURL: String
    private var stubs: [RequestType : [String : AnyObject]]
    private var token: String?
    private var imageCache = NSCache()

    /**
     Internal flag used to disable synchronous request when running automatic tests
     */
    internal var disableTestingMode = false

    private lazy var session: NSURLSession = {
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
    public func autenticate(username: String, password: String) {
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
    public func autenticate(token: String) {
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

// MARK: HTTP requests

extension Networking {
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

// MARK: Image

extension Networking {
    #if os(iOS) || os(tvOS) || os(watchOS)
    /**
    Downloads an image using the specified path.
    - parameter path: The path where the image is located
    - parameter completion: A closure that gets called when the image download request is completed, it contains an `UIImage` object and a `NSError`.
    */
    public func downloadImage(path: String, completion: (image: UIImage?, error: NSError?) -> ()) {
        let destinationURL = self.destinationURL(path)
        guard let filePath = self.destinationURL(path).path else { fatalError("File path not valid") }

        if let getStubs = self.stubs[.GET], image = getStubs[path] as? UIImage {
            completion(image: image, error: nil)
        } else if let image = self.imageCache.objectForKey(destinationURL.absoluteString) as? UIImage {
            completion(image: image, error: nil)
        } else if NSFileManager().fileExistsAtPath(filePath) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), {
                if let data = NSData(contentsOfURL: destinationURL), image = UIImage(data: data) {
                    dispatch_async(dispatch_get_main_queue(), {
                        completion(image: image, error: nil)
                    })
                    self.imageCache.setObject(image, forKey: filePath)
                }
            })
        } else {
            let request = NSMutableURLRequest(URL: self.urlForPath(path))
            request.HTTPMethod = RequestType.GET.rawValue
            request.addValue("application/json", forHTTPHeaderField: "Accept")

            if let token = token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let semaphore = dispatch_semaphore_create(0)
            var returnedData: NSData?
            var returnedImage: UIImage?
            var returnedError: NSError?
            var returnedResponse: NSURLResponse?

            #if os(iOS)
                if TestCheck.isTesting == false {
                    dispatch_async(dispatch_get_main_queue(), {
                        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
                    })
                }
            #endif

            self.session.downloadTaskWithRequest(request, completionHandler: { url, response, error in
                returnedResponse = response
                returnedError = error

                if let url = url, data = NSData(contentsOfURL: url), image = UIImage(data: data) {
                    returnedData = data
                    returnedImage = image

                    data.writeToURL(destinationURL, atomically: true)
                    self.imageCache.setObject(image, forKey: filePath)
                }

                if TestCheck.isTesting && self.disableTestingMode == false {
                    dispatch_semaphore_signal(semaphore)
                } else {
                    dispatch_async(dispatch_get_main_queue(), {
                        #if os(iOS)
                            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                        #endif

                        self.logError(nil, data: returnedData, request: request, response: response, error: error)
                        completion(image: returnedImage, error: error)
                    })
                }
            }).resume()

            if TestCheck.isTesting && self.disableTestingMode == false {
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

                self.logError(nil, data: returnedData, request: request, response: returnedResponse, error: returnedError)
                completion(image: returnedImage, error: returnedError)
            }
        }
    }

    /**
     Cancels the image download request for the specified path. This causes the request to complete with error code -999
     - parameter path: The path for the cancelled image download request
     */
    public func cancelImageDownload(path: String) {
        self.cancelRequest(.Download, requestType: .GET, path: path)
    }

    /**
     Stubs a download image request with an UIImage. After registering this, every download request to the path, will return
     the registered UIImage.
     - parameter path: The path for the stubbed image download.
     - parameter image: A UIImage that will be returned when there's a request to the registered path
     */
    public func stubImageDownload(path: String, image: UIImage) {
        self.stub(.GET, path: path, response: image)
    }
    #endif
}

// MARK: - Private

extension Networking {
    private func stub(requestType: RequestType, path: String, fileName: String, bundle: NSBundle = NSBundle.mainBundle()) {
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

    private func stub(requestType: RequestType, path: String, response: AnyObject) {
        var getStubs = self.stubs[requestType] ?? [String : AnyObject]()
        getStubs[path] = response
        self.stubs[requestType] = getStubs
    }

    private func request(requestType: RequestType, path: String, parameters: AnyObject?, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
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

            #if os(iOS)
                if TestCheck.isTesting == false {
                    dispatch_async(dispatch_get_main_queue(), {
                        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
                    })
                }
            #endif

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
                            #if os(iOS)
                                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                            #endif

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

    private func cancelRequest(sessionTaskType: SessionTaskType, requestType: RequestType, path: String) {
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

    private func logError(parameters: AnyObject? = nil, data: NSData?, request: NSURLRequest?, response: NSURLResponse?, error: NSError?) {
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
