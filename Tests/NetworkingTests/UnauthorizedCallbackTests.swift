import Foundation
import XCTest
@testable import Networking

class UnauthorizedCallbackTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testUnauthorizedCallback() async throws {
        let networking = Networking(baseURL: baseURL)
        var callbackExecuted = false

        networking.unauthorizedRequestCallback = {
            callbackExecuted = true
        }

        let _ = try await networking.get("/basic-auth/user/passwd")
        XCTAssertTrue(callbackExecuted)
    }

    func testCallbackWithFakedRequest() async throws {
        let networking = Networking(baseURL: baseURL)
        var callbackExecuted = false

        networking.unauthorizedRequestCallback = {
            callbackExecuted = true
        }

        networking.fakeGET("/hi-mom", response: nil, statusCode: 401)
        let _ = try await networking.get("/hi-mom")
        XCTAssertTrue(callbackExecuted)
    }
}
