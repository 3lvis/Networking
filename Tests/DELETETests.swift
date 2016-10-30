import Foundation
import XCTest

class DELETETests: XCTestCase {
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
            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            guard let url = JSON["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "http://httpbin.org/delete")

            guard let headers = JSON["headers"] as? [String: String] else { XCTFail(); return }
            let contentType = headers["Content-Type"]
            XCTAssertNil(contentType)
        }
    }

    func testDELETEWithHeaders() {
        let networking = Networking(baseURL: baseURL)
        networking.DELETE("/delete") { JSON, headers, error in
            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            guard let url = JSON["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "http://httpbin.org/delete")

            guard let connection = headers["Connection"] as? String else { XCTFail(); return }
            XCTAssertEqual(connection, "keep-alive")
            XCTAssertEqual(headers["Content-Type"] as? String, "application/json")
        }
    }

    func testDELETEWithInvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.DELETE("/invalidpath") { JSON, error in
            XCTAssertNil(JSON)
            XCTAssertEqual(error?.code, 404)
        }
    }

    func testFakeDELETE() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/stories", response: ["name": "Elvis"])

        networking.DELETE("/stories") { JSON, error in
            guard let JSON = JSON as? [String: String] else { XCTFail(); return }
            let value = JSON["name"]
            XCTAssertEqual(value, "Elvis")
        }
    }

    func testFakeDELETEWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/story", response: nil, statusCode: 401)

        networking.DELETE("/story") { JSON, error in
            XCTAssertEqual(error?.code, 401)
        }
    }

    func testFakeDELETEUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/entries", fileName: "entries.json", bundle: Bundle(for: DELETETests.self))

        networking.DELETE("/entries") { JSON, error in
            guard let JSON = JSON as? [[String: Any]] else { XCTFail(); return }
            let entry = JSON[0]
            let value = entry["title"] as? String
            XCTAssertEqual(value, "Entry 1")
        }
    }

    func testCancelDELETEWithPath() {
        let expectation = self.expectation(description: "testCancelDELETE")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        var completed = false
        networking.DELETE("/delete") { JSON, error in
            XCTAssertTrue(completed)
            XCTAssertEqual(error?.code, -999)
            expectation.fulfill()
        }

        networking.cancelDELETE("/delete") {
            completed = true
        }

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelDELETEWithID() {
        let expectation = self.expectation(description: "testCancelDELETE")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        var completed = false
        let requestID = networking.DELETE("/delete") { JSON, error in
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
