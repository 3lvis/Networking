import Foundation
import XCTest
@testable import Networking

class PATCHIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testPATCH() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<NetworkingResponse, NetworkingError> = await networking.patch("/patch", parameters: ["username": "jameson", "password": "secret"])
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

    func testPATCHWithHeaders() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<NetworkingResponse, NetworkingError> = await networking.patch("/patch")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/patch")
            XCTAssertTrue(response.headers.string(for: "Content-Type")?.hasPrefix("application/json") ?? false)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testPATCHWithIvalidPath() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<NetworkingResponse, NetworkingError> = await networking.patch("/posdddddt", parameters: ["username": "jameson", "password": "secret"])
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
}
