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

  }

  class func stubGET(path: String, response: AnyObject) {

  }
}
