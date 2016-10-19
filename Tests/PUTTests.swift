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
        networking.PUT("/put", parameters: ["username": "jameson", "password": "secret"]) { JSON, error in
            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            let JSONResponse = JSON["json"] as? [String: String]
            XCTAssertEqual("jameson", JSONResponse?["username"])
            XCTAssertEqual("secret", JSONResponse?["password"])
            XCTAssertNil(error)

            guard let headers = JSON["headers"] as? [String: String] else { XCTFail(); return }
            XCTAssertEqual(headers["Content-Type"], "application/json")
        }
    }

    func testPUTWithHeaders() {
        let networking = Networking(baseURL: baseURL)
        networking.PUT("/put") { JSON, headers, error in
            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            guard let url = JSON["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "http://httpbin.org/put")

            guard let connection = headers["Connection"] as? String else { XCTFail(); return }
            XCTAssertEqual(connection, "keep-alive")
            XCTAssertEqual(headers["Content-Type"] as? String, "application/json")
        }
    }

    func testPUTWithIvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.PUT("/posdddddt", parameters: ["username": "jameson", "password": "secret"]) { JSON, error in
            XCTAssertEqual(error?.code, 404)
            XCTAssertNil(JSON)
        }
    }

    func testFakePUT() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/story", response: [["name": "Elvis"]])

        networking.PUT("/story", parameters: ["username": "jameson", "password": "secret"]) { JSON, error in
            let JSON = JSON as? [[String: String]]
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

        networking.fakePUT("/entries", fileName: "entries.json", bundle: Bundle(for: PUTTests.self))

        networking.PUT("/entries", parameters: nil) { JSON, error in
            guard let JSON = JSON as? [[String: Any]] else { XCTFail(); return }
            let entry = JSON[0]
            let value = entry["title"] as? String
            XCTAssertEqual(value, "Entry 1")
        }
    }

    func testCancelPUTWithPath() {
        let expectation = self.expectation(description: "testCancelPUT")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        var completed = false
        networking.PUT("/put", parameters: ["username": "jameson", "password": "secret"]) { JSON, error in
            XCTAssertTrue(completed)
            XCTAssertEqual(error?.code, -999)
            expectation.fulfill()
        }

        networking.cancelPUT("/put") {
            completed = true
        }

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelPUTWithID() {
        let expectation = self.expectation(description: "testCancelPUT")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        var completed = false
        let requestID = networking.PUT("/put", parameters: ["username": "jameson", "password": "secret"]) { JSON, error in
            XCTAssertTrue(completed)
            XCTAssertEqual(error?.code, -999)
            expectation.fulfill()
        }

        networking.cancel(with: requestID) {
            completed = true
        }

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }
}
