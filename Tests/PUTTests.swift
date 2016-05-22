import Foundation
import XCTest

class PUTTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testSynchronousPUT() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.PUT("/put", parameters: nil) { JSON, error in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testPUT() {
        let networking = Networking(baseURL: baseURL)
        networking.PUT("/put", parameters: ["username" : "jameson", "password" : "secret"]) { JSON, error in
            guard let JSON = JSON as? [String : AnyObject] else { XCTFail(); return }
            let JSONResponse = JSON["json"] as? [String : String]
            XCTAssertEqual("jameson", JSONResponse?["username"])
            XCTAssertEqual("secret", JSONResponse?["password"])
            XCTAssertNil(error)
        }
    }

    func testPUTWithIvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.PUT("/posdddddt", parameters: ["username" : "jameson", "password" : "secret"]) { JSON, error in
            XCTAssertEqual(error?.code, 404)
            XCTAssertNil(JSON)
        }
    }

    func testFakePUT() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/story", response: [["name" : "Elvis"]])

        networking.PUT("/story", parameters: ["username" : "jameson", "password" : "secret"]) { JSON, error in
            let JSON = JSON as? [[String : String]]
            let value = JSON?[0]["name"]
            XCTAssertEqual(value, "Elvis")
        }
    }

    func testFakePUTWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/story", response: nil, statusCode: 401)

        networking.PUT("/story", parameters: nil) { JSON, error in
            XCTAssertEqual(error?.code, 401)
        }
    }

    func testFakePUTUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/entries", fileName: "entries.json", bundle: NSBundle(forClass: PUTTests.self))

        networking.PUT("/entries", parameters: nil) { JSON, error in
            guard let JSON = JSON as? [[String : AnyObject]] else { XCTFail(); return }
            let entry = JSON[0]
            let value = entry["title"] as? String
            XCTAssertEqual(value, "Entry 1")
        }
    }

    func testCancelPUT() {
        let expectation = expectationWithDescription("testCancelPUT")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.PUT("/put", parameters: ["username" : "jameson", "password" : "secret"]) { JSON, error in
            XCTAssertEqual(error?.code, -999)
            expectation.fulfill()
        }

        networking.cancelPUT("/put")

        waitForExpectationsWithTimeout(15.0, handler: nil)
    }
}