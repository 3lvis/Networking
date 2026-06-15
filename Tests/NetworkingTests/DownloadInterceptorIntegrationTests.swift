import Foundation
import XCTest
@testable import Networking

// Downloads should run through the same interceptor chain as the verbs, so retry/auth-refresh apply to
// them too. A pass-through interceptor records that it saw the request.
final class DownloadInterceptorIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    private actor Counter {
        private(set) var count = 0
        func tick() { count += 1 }
    }

    private struct CountingPassthroughInterceptor: HTTPInterceptor {
        let counter: Counter
        func intercept(_ request: URLRequest, next: @Sendable (URLRequest) async throws -> HTTPExchange) async throws -> HTTPExchange {
            await counter.tick()
            return try await next(request)
        }
    }

    func testDownloadsRunThroughInterceptors() async {
        let networking = Networking(baseURL: baseURL)
        let counter = Counter()
        await networking.setInterceptors([CountingPassthroughInterceptor(counter: counter)])

        let result: Result<Data, NetworkingError> = await networking.downloadData("/bytes/16", cachingLevel: .none)

        if case let .failure(error) = result { XCTFail("expected the download to succeed, got \(error)") }
        let count = await counter.count
        XCTAssertGreaterThanOrEqual(count, 1, "a download must pass through the interceptor chain")
    }
}
