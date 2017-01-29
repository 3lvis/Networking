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
        networking.GET("/basic-auth/user/passwd") { _, _ in
            ignoredCompletionBlock = false
        }

        XCTAssertTrue(callbackExecuted)
        XCTAssertTrue(ignoredCompletionBlock)
    }

    func testCallbackWithFakedRequest() {
        let networking = Networking(baseURL: baseURL)
        var callbackExecuted = false

        networking.unauthorizedRequestCallback = {
            callbackExecuted = true
        }

        var ignoredCompletionBlock = true
        networking.fakeGET("/hi-mom", response: nil, statusCode: 401)
        networking.GET("/hi-mom") { _, _ in
            ignoredCompletionBlock = false
        }

        XCTAssertTrue(callbackExecuted)
        XCTAssertTrue(ignoredCompletionBlock)
    }
}
