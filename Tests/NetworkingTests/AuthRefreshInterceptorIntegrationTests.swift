import Foundation
import XCTest

@testable import Networking

// go-httpbin's /bearer returns 401 without an `Authorization: Bearer …` header and 200 with one — so it
// exercises the full refresh + replay path: the first attempt is unauthorized, the interceptor supplies a
// credential, and the replay succeeds.
final class AuthRefreshInterceptorIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testReplaysUnauthorizedWithRefreshedCredential() async throws {
        let networking = Networking(baseURL: baseURL)
        await networking.setInterceptors([
            AuthRefreshInterceptor { "Bearer refreshed-token" }
        ])

        // No Authorization header is set, so the first attempt is a 401; the interceptor must refresh + replay.
        let result: Result<JSONResponse, NetworkingError> = await networking.get("/bearer")

        switch result {
        case .success(let response):
            XCTAssertEqual(response.statusCode, 200, "the replay with a fresh credential should succeed")
        case .failure(let error):
            XCTFail("expected the refreshed replay to succeed, got \(error)")
        }
    }
}
