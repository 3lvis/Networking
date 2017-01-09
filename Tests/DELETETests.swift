import Foundation
import XCTest

class DELETETests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testSynchronousDELETE() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.DELETE("/delete") { json, error in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testDELETE() {
        let networking = Networking(baseURL: baseURL)
        networking.DELETE("/delete") { json, error in
            guard let json = json as? [String: Any] else { XCTFail(); return }
            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "http://httpbin.org/delete")

            guard let headers = json["headers"] as? [String: String] else { XCTFail(); return }
            let contentType = headers["Content-Type"]
            XCTAssertNil(contentType)
        }
    }

    func testDELETEWithHeaders() {
        let networking = Networking(baseURL: baseURL)
        networking.DELETE("/delete") { json, headers, error in
            guard let json = json as? [String: Any] else { XCTFail(); return }
            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "http://httpbin.org/delete")

            guard let connection = headers["Connection"] as? String else { XCTFail(); return }
            XCTAssertEqual(connection, "keep-alive")
            XCTAssertEqual(headers["Content-Type"] as? String, "application/json")
        }
    }

    func testDELETEWithInvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.DELETE("/invalidpath") { json, error in
            XCTAssertNil(json)
            XCTAssertEqual(error?.code, 404)
        }
    }

    func testFakeDELETE() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/stories", response: ["name": "Elvis"])

        networking.DELETE("/stories") { json, error in
            guard let json = json as? [String: String] else { XCTFail(); return }
            let value = json["name"]
            XCTAssertEqual(value, "Elvis")
        }
    }

    func testFakeDELETEWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/story", response: nil, statusCode: 401)

        networking.DELETE("/story") { json, error in
            XCTAssertEqual(error?.code, 401)
        }
    }

    func testFakeDELETEUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/entries", fileName: "entries.json", bundle: Bundle(for: DELETETests.self))

        networking.DELETE("/entries") { json, error in
            guard let json = json as? [[String: Any]] else { XCTFail(); return }
            let entry = json[0]
            let value = entry["title"] as? String
            XCTAssertEqual(value, "Entry 1")
        }
    }

    func testCancelDELETEWithPath() {
        let expectation = self.expectation(description: "testCancelDELETE")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        var completed = false
        networking.DELETE("/delete") { json, error in
            XCTAssertTrue(completed)
            XCTAssertEqual(error?.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }

        networking.cancelDELETE("/delete")
        completed = true

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelDELETEWithID() {
        let expectation = self.expectation(description: "testCancelDELETE")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        var completed = false
        let requestID = networking.DELETE("/delete") { json, error in
            XCTAssertTrue(completed)
            XCTAssertEqual(error?.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }

        networking.cancel(with: requestID) {
            completed = true
        }

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testDELETEWithURLEncodedParameters() {
        let networking = Networking(baseURL: baseURL)
        networking.DELETE("/delete", parameters: ["userId": 25]) { json, error in
            let json = json as? [String: Any] ?? [String: Any]()
            XCTAssertEqual(json["url"] as? String, "http://httpbin.org/delete?userId=25")
        }
    }
}
