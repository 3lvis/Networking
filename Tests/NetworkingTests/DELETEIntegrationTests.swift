import Foundation
import XCTest
@testable import Networking

class DELETEIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testDELETE() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.delete("/delete")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/delete")
            XCTAssertNil(httpbinEchoedMap(response, "headers")["Content-Type"])
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testDELETEWithHeaders() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.delete("/delete")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/delete")
            XCTAssertTrue(response.headers.string(for: "Content-Type")?.hasPrefix("application/json") ?? false)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testDELETEWithInvalidPath() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.delete("/invalidpath")
        switch result {
        case .success:
            XCTFail()
        case let .failure(error):
            guard case let .clientError(statusCode, _) = error else {
                return XCTFail("expected a client error, got \(error)")
            }
            XCTAssertEqual(statusCode, 404)
        }
    }

    func testDELETEWithURLEncodedParameters() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.delete("/delete", parameters: ["userId": 25])
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/delete?userId=25")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

}
