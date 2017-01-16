import Foundation
import XCTest

class UnauthorizedCallbackTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testUnauthorizedCallback() {
        let networking = Networking(baseURL: baseURL)
        var callbackExecuted = false

        networking.unauthorizedRequestCallback = {
            callbackExecuted = true
        }

        var ignoredCompletionBlock = true
        networking.GET("/basic-auth/user/passwd") { JSON, error in
            ignoredCompletionBlock = false
        }

        XCTAssertTrue(callbackExecuted)
        XCTAssertTrue(ignoredCompletionBlock)
    }
}
