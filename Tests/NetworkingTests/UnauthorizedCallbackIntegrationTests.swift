import Foundation
import XCTest
@testable import Networking

class UnauthorizedCallbackIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testUnauthorizedCallback() async throws {
        let networking = Networking(baseURL: baseURL)
        var callbackExecuted = false

        networking.unauthorizedRequestCallback = {
            callbackExecuted = true
        }

        let _: Result<NetworkingResponse, NetworkingError> = await networking.get("/basic-auth/user/passwd")
        XCTAssertTrue(callbackExecuted)
    }
}
