import Foundation
import XCTest
@testable import Networking

// When many requests hit an expired credential at once, they must share a single refresh rather than each
// firing its own (the classic OkHttp token-refresh stampede). The refresh closure here is deliberately slow
// so all the concurrent requests are awaiting it together before the first one finishes.
final class AuthRefreshSingleFlightIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    private actor RefreshCounter {
        private(set) var count = 0
        func increment() { count += 1 }
    }

    func testConcurrentUnauthorizedRequestsShareOneRefresh() async throws {
        let networking = Networking(baseURL: baseURL)
        let counter = RefreshCounter()
        await networking.setInterceptors([
            AuthRefreshInterceptor {
                await counter.increment()
                try? await Task.sleep(for: .milliseconds(100))
                return "Bearer refreshed-token"
            }
        ])

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    let _: Result<JSONResponse, NetworkingError> = await networking.get("/bearer")
                }
            }
        }

        let count = await counter.count
        XCTAssertEqual(count, 1, "concurrent 401s should share a single refresh, but it ran \(count) times")
    }
}
