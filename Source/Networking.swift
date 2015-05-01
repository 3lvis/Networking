import Foundation
import UIKit
import NSObject_HYPTesting

class Networking {
  private let baseURL: NSString
  private var stubbedResponses: [String : [String : AnyObject]]

  static let stubsInstance = Networking(baseURL: "")

  init(baseURL: String) {
    self.baseURL = baseURL
    self.stubbedResponses = [String : [String : AnyObject]]()
  }

  func GET(path: String, completion: (JSON: [String : AnyObject], error: NSError?) -> ()) {
    let url = String(format: "%@%@", self.baseURL, path)
    let request = NSURLRequest(URL: NSURL(string: url)!)

    if NSObject.isUnitTesting() {
      let responses = Networking.stubsInstance.stubbedResponses
      if let response: [String : AnyObject] = responses[path] {
        completion(JSON: response, error: nil)
      } else {
        var error: NSError?
        var response: NSURLResponse?
        let data = NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error: &error)
        let result = data?.JSON()
        if error == nil {
          error = result!.error
        }

        completion(JSON: result!.JSON!, error: error)
      }
    } else {
      UIApplication.sharedApplication().networkActivityIndicatorVisible = true

      let queue = NSOperationQueue()
      NSURLConnection.sendAsynchronousRequest(request, queue: queue, completionHandler: { (response, data, error) -> Void in
        let result = data?.JSON()
        dispatch_async(dispatch_get_main_queue(), {
          UIApplication.sharedApplication().networkActivityIndicatorVisible = false

          completion(JSON: result!.JSON!, error: error)
        })
      })
    }
  }

  class func stubGET(path: String, response: AnyObject) {

  }
}

extension NSData {
  func JSON() -> (JSON: [String : AnyObject]?, error: NSError?) {
    var error: NSError?
    let JSON = NSJSONSerialization.JSONObjectWithData(self, options: NSJSONReadingOptions.MutableContainers, error: &error) as! [String : AnyObject]

    return (JSON, error)
  }
}
