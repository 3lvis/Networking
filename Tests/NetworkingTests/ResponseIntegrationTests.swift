import XCTest
@testable import Networking

class ResponseIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testReflectsRequestHeaderInBody() async throws {
        let networking = Networking(baseURL: baseURL)
        let expectedUserAgent = "hi mom!"
        await networking.setHeaderFields(["user-agent": expectedUserAgent])
        let result: Result<JSONResponse, NetworkingError> = await networking.get("/user-agent")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "user-agent"), expectedUserAgent)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }
}
