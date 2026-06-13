import Foundation
import XCTest
@testable import Networking

class UnauthorizedCallbackTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testCallbackWithFakedRequest() async throws {
        let networking = Networking(baseURL: baseURL)
        var callbackExecuted = false

        networking.unauthorizedRequestCallback = {
            callbackExecuted = true
        }

        networking.fakeGET("/hi-mom", response: nil, statusCode: 401)
        let _: Result<NetworkingResponse, NetworkingError> = await networking.get("/hi-mom")
        XCTAssertTrue(callbackExecuted)
    }
}
