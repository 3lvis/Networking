import Foundation
import XCTest

class HTTPDELETERequestTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testSynchronousDELETE() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.DELETE("/delete") { JSON, error in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testDELETE() {
        let networking = Networking(baseURL: baseURL)
        networking.DELETE("/delete") { JSON, error in
            let JSON = JSON as! [String : AnyObject]
            let url = JSON["url"] as! String
            XCTAssertEqual(url, "http://httpbin.org/delete")
        }
    }

    func testDELETEWithInvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.DELETE("/invalidpath") { JSON, error in
            XCTAssertNil(JSON)
            XCTAssertEqual(error!.code, 404)
        }
    }

    func testFakeDELETE() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/stories", response: ["name" : "Elvis"])

        networking.DELETE("/stories") { JSON, error in
            let JSON = JSON as! [String : String]
            let value = JSON["name"]
            XCTAssertEqual(value!, "Elvis")
        }
    }

    func testFakeDELETEWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/story", response: nil, statusCode: 401)

        networking.DELETE("/story") { JSON, error in
            XCTAssertEqual(401, error!.code)
        }
    }

    func testFakeDELETEUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/entries", fileName: "entries.json", bundle: NSBundle(forClass: self.classForKeyedArchiver!))

        networking.DELETE("/entries") { JSON, error in
            let JSON = JSON as! [[String : AnyObject]]
            let entry = JSON[0]
            let value = entry["title"] as! String
            XCTAssertEqual(value, "Entry 1")
        }
    }

    func testCancelDELETE() {
        let expectation = expectationWithDescription("testCancelDELETE")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.DELETE("/delete") { JSON, error in
            let canceledCode = error!.code == -999
            XCTAssertTrue(canceledCode)

            expectation.fulfill()
        }

        networking.cancelDELETE("/delete")

        waitForExpectationsWithTimeout(15.0, handler: nil)
    }
}
