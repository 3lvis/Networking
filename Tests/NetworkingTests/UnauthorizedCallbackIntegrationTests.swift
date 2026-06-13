import Foundation
import XCTest
@testable import Networking

class UnauthorizedCallbackIntegrationTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testUnauthorizedCallback() async throws {
        let networking = Networking(baseURL: baseURL)
        var callbackExecuted = false

        networking.unauthorizedRequestCallback = {
            callbackExecuted = true
        }

        let _ = try await networking.oldGet("/basic-auth/user/passwd")
        XCTAssertTrue(callbackExecuted)
    }
}
