import Foundation
import XCTest

class DELETETests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testSynchronousDELETE() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.delete("/delete") { _ in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testDELETE() {
        let networking = Networking(baseURL: baseURL)
        networking.delete("/delete") { result in
            switch result {
            case .success(let response):
                let json = response.dictionaryBody
                guard let url = json["url"] as? String else { XCTFail(); return }
                XCTAssertEqual(url, "http://httpbin.org/delete")

                guard let headers = json["headers"] as? [String: String] else { XCTFail(); return }
                let contentType = headers["Content-Type"]
                XCTAssertNil(contentType)
            case .failure:
                XCTFail()
            }
        }
    }

    func testDELETEWithHeaders() {
        let networking = Networking(baseURL: baseURL)
        networking.delete("/delete") { result in
            switch result {
            case .success(let response):
                let json = response.dictionaryBody
                guard let url = json["url"] as? String else { XCTFail(); return }
                XCTAssertEqual(url, "http://httpbin.org/delete")

                let headers = response.headers
                guard let connection = headers["Connection"] as? String else { XCTFail(); return }
                XCTAssertEqual(connection, "keep-alive")
                XCTAssertEqual(headers["Content-Type"] as? String, "application/json")
            case .failure:
                XCTFail()
            }
        }
    }

    func testDELETEWithInvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.delete("/invalidpath") { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(let response):
                XCTAssertEqual(response.error.code, 404)
            }
        }
    }

    func testFakeDELETE() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/stories", response: ["name": "Elvis"])

        networking.delete("/stories") { result in
            switch result {
            case .success(let response):
                let json = response.dictionaryBody
                let value = json["name"] as? String
                XCTAssertEqual(value, "Elvis")
            case .failure:
                XCTFail()
            }
        }
    }

    func testFakeDELETEWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/story", response: nil, statusCode: 401)

        networking.delete("/story") { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(let response):
                XCTAssertEqual(response.error.code, 401)
            }
        }
    }

    func testFakeDELETEUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/entries", fileName: "entries.json", bundle: Bundle(for: DELETETests.self))

        networking.delete("/entries") { result in
            switch result {
            case .success(let response):
                let json = response.arrayBody
                let entry = json[0]
                let value = entry["title"] as? String
                XCTAssertEqual(value, "Entry 1")
            case .failure:
                XCTFail()
            }
        }
    }

    func testCancelDELETEWithPath() {
        let expectation = self.expectation(description: "testCancelDELETE")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        var completed = false
        networking.delete("/delete") { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(let response):
                XCTAssertTrue(completed)
                XCTAssertEqual(response.error.code, URLError.cancelled.rawValue)
                expectation.fulfill()
            }
        }

        networking.cancelDELETE("/delete")
        completed = true

        waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelDELETEWithID() {
        let expectation = self.expectation(description: "testCancelDELETE")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        let requestID = networking.delete("/delete") { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(let response):
                XCTAssertEqual(response.error.code, URLError.cancelled.rawValue)
                expectation.fulfill()
            }
        }

        networking.cancel(with: requestID)

        waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testDELETEWithURLEncodedParameters() {
        let networking = Networking(baseURL: baseURL)
        networking.delete("/delete", parameters: ["userId": 25]) { result in
            switch result {
            case .success(let response):
                let json = response.dictionaryBody
                XCTAssertEqual(json["url"] as? String, "http://httpbin.org/delete?userId=25")
            case .failure:
                XCTFail()
            }
        }
    }
}
