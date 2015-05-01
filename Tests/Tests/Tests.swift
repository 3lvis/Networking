import Foundation
import XCTest

class Tests: XCTestCase {
  let baseURL = "http://httpbin.org"

  func testGET() {
    var success = false

    let networking = Networking(baseURL: baseURL)
    networking.GET("/get", completion: { (JSON, error) in
      let url = JSON["url"] as! String
      XCTAssertEqual(url, "http://httpbin.org/get")
      XCTAssertNil(error!)
      success = true
    })

    XCTAssertTrue(success)
  }
}
