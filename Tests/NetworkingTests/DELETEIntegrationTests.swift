import Foundation
import XCTest

@testable import Networking

class DELETEIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testDELETE() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.delete("/delete")
        switch result {
        case .success(let response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/delete")
            XCTAssertNil(httpbinEchoedMap(response, "headers")["Content-Type"])
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }

    func testDELETEWithHeaders() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.delete("/delete")
        switch result {
        case .success(let response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/delete")
            XCTAssertTrue(response.headers.string(for: "Content-Type")?.hasPrefix("application/json") ?? false)
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }

    func testDELETEWithInvalidPath() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.delete("/invalidpath")
        switch result {
        case .success:
            XCTFail()
        case .failure(let error):
            guard case .http(let httpError) = error else {
                return XCTFail("expected an HTTP error, got \(error)")
            }
            XCTAssertEqual(httpError.statusCode, 404)
        }
    }

    func testDELETEWithURLEncodedParameters() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.delete(
            "/delete", query: [URLQueryItem(name: "userId", value: "25")])
        switch result {
        case .success(let response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/delete?userId=25")
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }

}
