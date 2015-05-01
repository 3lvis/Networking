import Foundation
import UIKit

class Networking {
  private let baseURL: NSString
  private var stubbedResponses: [String : AnyObject]

  static let stubsInstance = Networking(baseURL: "")

  init(baseURL: String) {
    self.baseURL = baseURL
    self.stubbedResponses = [String : AnyObject]()
  }

  func GET(path: String, completion: (JSON: [String : AnyObject], error: NSError?) -> ()) {
    UIApplication.sharedApplication().networkActivityIndicatorVisible = true

    let url = String(format: "%@%@", self.baseURL, path)
    let request = NSURLRequest(URL: NSURL(string: url)!)

//    if NSObject.isUnitTesting() {
//
//    }
  }

  class func stubGET(path: String, response: AnyObject) {

  }
}
