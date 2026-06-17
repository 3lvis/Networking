import Foundation
import XCTest
import CoreLocation
@testable import Networking

class NewNetworkingTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    struct ValidationErrors: Decodable { let errors: [String: [String]] }

    func testErrorNetworkingJSON() async throws {
        let networking = Networking(baseURL: baseURL)

        let response = [
            "errors": [
                "phone_number": ["has already been taken"]
            ]
        ]
        await networking.fakePOST("/auth", response: response, statusCode: 422)

        let result: Result<JSONResponse, NetworkingError> = await networking.post("/auth")
        switch result {
        case .success:
            XCTFail("expected a 422 failure")
        case .failure(let error):
            guard case let .http(httpError) = error else {
                return XCTFail("expected an HTTP error, got \(error)")
            }
            XCTAssertEqual(httpError.statusCode, 422)
            let decoded = try httpError.metadata.decode(ValidationErrors.self)
            XCTAssertEqual(decoded.errors["phone_number"], ["has already been taken"])
        }
    }
}
