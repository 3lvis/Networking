import Foundation
import UIKit
import NSObject_HYPTesting
import JSON

public class Networking {
    private let baseURL: String
    private var stubbedResponses: [String : AnyObject]
    private static let stubsInstance = Networking(baseURL: "")

    public init(baseURL: String) {
        self.baseURL = baseURL
        self.stubbedResponses = [String : AnyObject]()
    }

    // MARK: GET

    public func GET(path: String, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        let request = NSURLRequest(URL: self.urlForPath(path))

        let responses = Networking.stubsInstance.stubbedResponses
        if let response = responses[path] {
            completion(JSON: response, error: nil)
        } else {
            if NSObject.isUnitTesting() == false {
                dispatch_async(dispatch_get_main_queue(), {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = true
                })
            }

            let semaphore = dispatch_semaphore_create(0)
            var connectionError: NSError?
            var result: AnyObject?
            NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { data, _, error in
                if let data = data {
                    (result, connectionError) = data.toJSON()
                } else if let error = error {
                    connectionError = error
                }

                if NSObject.isUnitTesting() {
                    dispatch_semaphore_signal(semaphore)
                } else {
                    dispatch_async(dispatch_get_main_queue(), {
                        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                        completion(JSON: result, error: connectionError)
                    })
                }
            }).resume()

            if NSObject.isUnitTesting() {
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
                completion(JSON: result, error: connectionError)
            }
        }
    }

    public class func stubGET(path: String, response: [String : AnyObject]) {
        stubsInstance.stubbedResponses[path] = response
    }

    // TODO: Return error
    public class func stubGET(path: String, fileName: String, bundle: NSBundle = NSBundle.mainBundle()) {
        let (result, _) = JSON.from(fileName, bundle: bundle)
        stubsInstance.stubbedResponses[path] = result
    }

    // MARK: POST

    public func POST(path: String, params: AnyObject?, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
        dispatch_async(dispatch_get_main_queue(), {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        })

        let url = String(format: "%@%@", self.baseURL, path)
        let request = NSMutableURLRequest(URL: NSURL(string: url)!)

        let session = NSURLSession.sharedSession()
        request.HTTPMethod = "POST"

        if let params: AnyObject = params {
            var serializingError: NSError?
            do {
                request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(params, options: [])
            } catch let error as NSError {
                serializingError = error
                request.HTTPBody = nil
            }
            if serializingError != nil {
                dispatch_async(dispatch_get_main_queue(), {
                    completion(JSON: nil, error: serializingError)
                })
                return
            }
        }

        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let task = session.dataTaskWithRequest(request, completionHandler: { data, response, error in
            var serializingError: NSError? = nil
            var json: AnyObject?
            do {
                json = try NSJSONSerialization.JSONObjectWithData(data!, options: .MutableLeaves)
            } catch let error as NSError {
                serializingError = error
            }

            dispatch_async(dispatch_get_main_queue(), {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false

                if error == nil && serializingError == nil {
                    if let json = json {
                        completion(JSON: json, error: nil)
                    } else {
                        abort()
                    }
                } else if error != nil {
                    completion(JSON: nil, error: error)
                } else if serializingError != nil {
                    completion(JSON: nil, error: serializingError)
                }
            })
        })
        
        task.resume()
    }
    
    public func urlForPath(path: String) -> NSURL {
        return NSURL(string: self.baseURL + path)!
    }
}
