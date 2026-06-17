import Foundation
import XCTest
@testable import Networking

private struct Credentials: Codable, Equatable {
    let username: String
    let age: Int
    let active: Bool
}

// httpbin echoes a posted JSON body back under the top-level `json` key, and request headers
// under `headers` with each value as an array.
private struct BodyEcho: Decodable {
    let json: Credentials
    let headers: [String: [String]]
}

final class TypedRequestBodyIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testPOSTWithTypedBodyRoundTrips() async throws {
        let networking = Networking(baseURL: baseURL)
        let body = Credentials(username: "jameson", age: 20, active: true)
        let result: Result<BodyEcho, NetworkingError> = await networking.post("/post", body: body)
        switch result {
        case let .success(echo):
            XCTAssertEqual(echo.json, body)
            XCTAssertEqual(echo.headers["Content-Type"]?.first, "application/json")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testPOSTWithTypedBodyVoidReturn() async throws {
        let networking = Networking(baseURL: baseURL)
        let body = Credentials(username: "jameson", age: 20, active: true)
        let result: Result<Void, NetworkingError> = await networking.post("/post", body: body)
        if case let .failure(error) = result {
            XCTFail(error.localizedDescription)
        }
    }

    func testPUTWithTypedBodyRoundTrips() async throws {
        let networking = Networking(baseURL: baseURL)
        let body = Credentials(username: "ada", age: 36, active: false)
        let result: Result<BodyEcho, NetworkingError> = await networking.put("/put", body: body)
        switch result {
        case let .success(echo):
            XCTAssertEqual(echo.json, body)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testPATCHWithTypedBodyRoundTrips() async throws {
        let networking = Networking(baseURL: baseURL)
        let body = Credentials(username: "grace", age: 45, active: true)
        let result: Result<BodyEcho, NetworkingError> = await networking.patch("/patch", body: body)
        switch result {
        case let .success(echo):
            XCTAssertEqual(echo.json, body)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }
}
