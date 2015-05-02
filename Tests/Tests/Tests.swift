import Foundation
import XCTest

class Tests: XCTestCase {
  let baseURL = "http://httpbin.org"

  func testGET() {
    var success = false

    let networking = Networking(baseURL: baseURL)
    networking.GET("/get", completion: { JSON, error in
      if let JSON = JSON as? [String : AnyObject] {
        let url = JSON["url"] as! String
        XCTAssertEqual(url, "http://httpbin.org/get")
        success = true
      }
    })

    XCTAssertTrue(success)
  }

  func testGETWithInvalidPath() {
    var success = false

    let networking = Networking(baseURL: baseURL)
    networking.GET("invalidpath", completion: { JSON, error in
      if let JSON: AnyObject = JSON {
        fatalError("JSON not nil: \(JSON)")
      } else {
        if let error = error {
          XCTAssertNotNil(error)
          success = true
        }
      }
    })

    XCTAssertTrue(success)
  }

  func testGETStubs() {
    Networking.stubGET("/stories", response: ["name" : "Elvis"])

    var success = false
    let networking = Networking(baseURL: baseURL)
    networking.GET("/stories", completion: { JSON, error in
      if let JSON = JSON as? [String : String] {
        let value = JSON["name"]
        XCTAssertEqual(value!, "Elvis")
        success = true
      }
    })

    XCTAssertTrue(success)
  }
}
