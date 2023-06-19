import Foundation
import XCTest
@testable import Networking

class DELETETests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testDELETE() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.delete("/delete")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "http://httpbin.org/delete")

            guard let headers = json["headers"] as? [String: String] else { XCTFail(); return }
            let contentType = headers["Content-Type"]
            XCTAssertNil(contentType)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testDELETEWithHeaders() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.delete("/delete")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "http://httpbin.org/delete")

            let headers = response.headers
            XCTAssertEqual(headers["Content-Type"] as? String, "application/json")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testDELETEWithInvalidPath() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.delete("/invalidpath")
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertEqual(response.error.code, 404)
        }
    }

    // Disabling because I haven't found a way to test cancel
    /*
    func testCancelDELETEWithPath() {
        let expectation = self.expectation(description: "testCancelDELETE")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        var completed = false
        networking.delete("/delete") { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                print(response.error)

                XCTAssertTrue(completed)
                XCTAssertEqual(response.error.code, URLError.cancelled.rawValue)
                expectation.fulfill()
            }
        }

        networking.cancelDELETE("/delete")
        completed = true

        waitForExpectations(timeout: 15.0, handler: nil)
    }*/

    func testDELETEWithURLEncodedParameters() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.delete("/delete", parameters: ["userId": 25])
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["url"] as? String, "http://httpbin.org/delete?userId=25")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }
}
