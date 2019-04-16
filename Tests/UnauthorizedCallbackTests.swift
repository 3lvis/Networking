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
        networking.get("/basic-auth/user/passwd") { _ in
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
        networking.get("/hi-mom") { _ in
            ignoredCompletionBlock = false
        }

        XCTAssertTrue(callbackExecuted)
        XCTAssertTrue(ignoredCompletionBlock)
    }
}
