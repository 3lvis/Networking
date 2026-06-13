import Foundation
import XCTest
@testable import Networking

class UnauthorizedCallbackIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testUnauthorizedCallback() async throws {
        let networking = Networking(baseURL: baseURL)
        let callbackExecuted = Box(false)

        await networking.setUnauthorizedRequestCallback {
            callbackExecuted.value = true
        }

        let _: Result<JSONResponse, NetworkingError> = await networking.get("/basic-auth/user/passwd")
        XCTAssertTrue(callbackExecuted.value)
    }
}
