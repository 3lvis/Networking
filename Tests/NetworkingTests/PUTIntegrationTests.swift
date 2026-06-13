import Foundation
import XCTest
@testable import Networking

class PUTIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testPUT() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldPut("/put", parameters: ["username": "jameson", "password": "secret"])
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            let JSONResponse = json["json"] as? [String: String]
            XCTAssertEqual("jameson", JSONResponse?["username"])
            XCTAssertEqual("secret", JSONResponse?["password"])

            let headers = httpbinEchoedMap(json, "headers")
            XCTAssertEqual(headers["Content-Type"], "application/json")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testPUTWithHeaders() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldPut("/put")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "\(TestConfig.httpbinBaseURL)/put")

            let headers = response.headers
            XCTAssertTrue((headers["Content-Type"] as? String)?.hasPrefix("application/json") ?? false)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testPUTWithIvalidPath() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldPut("/posdddddt", parameters: ["username": "jameson", "password": "secret"])
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertEqual(response.error.code, 404)
        }
    }

    // Disabling because I haven't found a way to test cancel
    /*
    func testCancelPUTWithPath() async throws {
        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        var completed = false
        let result = try await networking.oldPut("/put", parameters: ["username": "jameson", "password": "secret"])
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertTrue(completed)
            XCTAssertEqual(response.error.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }

        networking.cancelPUT("/put")
        completed = true

        waitForExpectations(timeout: 150.0, handler: nil)
    }*/
}
