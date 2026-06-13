import Foundation
import XCTest
@testable import Networking

class DELETEIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testDELETE() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldDelete("/delete")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "\(TestConfig.httpbinBaseURL)/delete")

            let headers = httpbinEchoedMap(json, "headers")
            let contentType = headers["Content-Type"]
            XCTAssertNil(contentType)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testDELETEWithHeaders() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldDelete("/delete")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "\(TestConfig.httpbinBaseURL)/delete")

            let headers = response.headers
            XCTAssertTrue((headers["Content-Type"] as? String)?.hasPrefix("application/json") ?? false)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testDELETEWithInvalidPath() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldDelete("/invalidpath")
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
        networking.oldDelete("/delete") { result in
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
}
