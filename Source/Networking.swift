import Foundation
import UIKit
import NSObject_HYPTesting
import JSON

public class Networking {
  private let baseURL: NSString
  private var stubbedResponses: [String : AnyObject]
  private static let stubsInstance = Networking(baseURL: "")

  public init(baseURL: String) {
    self.baseURL = baseURL
    self.stubbedResponses = [String : AnyObject]()
  }

  public func GET(path: String, completion: (JSON: AnyObject?, error: NSError?) -> ()) {
    let url = String(format: "%@%@", self.baseURL, path)
    let request = NSURLRequest(URL: NSURL(string: url)!)

    let responses = Networking.stubsInstance.stubbedResponses
    if let response: AnyObject = responses[path] {
      completion(JSON: response, error: nil)
    } else if NSObject.isUnitTesting() {
      var connectionError: NSError?
      var response: NSURLResponse?
      var result: AnyObject?

      if let data = NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error: &connectionError) {
        var error: NSError?
        (result, error) = data.toJSON()

        if connectionError == nil {
          connectionError = error
        }
      }

      completion(JSON: result, error: connectionError)
    } else {
      UIApplication.sharedApplication().networkActivityIndicatorVisible = true

      let queue = NSOperationQueue()
      NSURLConnection.sendAsynchronousRequest(request, queue: queue, completionHandler: { (_, data: NSData?, error) in
        dispatch_async(dispatch_get_main_queue(), {
          UIApplication.sharedApplication().networkActivityIndicatorVisible = false
          var connectionError: NSError?
          var result: AnyObject?
          if let data = data {
            var jsonError: NSError?
            (result, jsonError) = data.toJSON()
            connectionError = error ?? jsonError
          }

          completion(JSON: result, error: connectionError)
        })
      })
    }
  }

  public class func stubGET(path: String, response: [String : AnyObject]) {
    stubsInstance.stubbedResponses[path] = response
  }

  public class func stubGET(path: String, fileName: String, bundle: NSBundle = NSBundle.mainBundle()) {
    let (result: AnyObject?, _) = JSON.from(fileName, bundle: bundle)
    stubsInstance.stubbedResponses[path] = result
  }
}
