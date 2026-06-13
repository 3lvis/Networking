import Foundation
import XCTest
@testable import Networking

class UnauthorizedCallbackTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testCallbackWithFakedRequest() async throws {
        let networking = Networking(baseURL: baseURL)
        let callbackExecuted = Box(false)

        await networking.setUnauthorizedRequestCallback {
            callbackExecuted.value = true
        }

        await networking.fakeGET("/hi-mom", response: nil, statusCode: 401)
        let _: Result<JSONResponse, NetworkingError> = await networking.get("/hi-mom")
        XCTAssertTrue(callbackExecuted.value)
    }
}
