import Foundation
import XCTest
@testable import Networking

class PUTIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testPUT() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.put("/put", body: ["username": "jameson", "password": "secret"])
        switch result {
        case let .success(response):
            let json = httpbinEchoedMap(response, "json")
            XCTAssertEqual(json["username"], "jameson")
            XCTAssertEqual(json["password"], "secret")

            let headers = httpbinEchoedMap(response, "headers")
            XCTAssertEqual(headers["Content-Type"], "application/json")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testPUTWithHeaders() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.put("/put")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/put")
            XCTAssertTrue(response.headers.string(for: "Content-Type")?.hasPrefix("application/json") ?? false)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testPUTWithIvalidPath() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.put("/posdddddt", body: ["username": "jameson", "password": "secret"])
        switch result {
        case .success:
            XCTFail()
        case let .failure(error):
            guard case let .http(httpError) = error else {
                return XCTFail("expected an HTTP error, got \(error)")
            }
            XCTAssertEqual(httpError.statusCode, 404)
        }
    }
}
