import Foundation
import XCTest
import CoreLocation
@testable import Networking

class NewNetworkingTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

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
        case .success(_): break
        case .failure(let response):
            XCTAssertTrue(response.errorDescription!.contains("has already been taken"))
        }
    }
}
