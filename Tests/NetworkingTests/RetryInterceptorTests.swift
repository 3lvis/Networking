import Foundation
import XCTest

@testable import Networking

// Retry behavior is exercised with a scripted innermost interceptor that short-circuits (returns a canned
// response or throws) instead of hitting the network, so the tests are deterministic and fast. It records
// how many attempts the RetryInterceptor made. Backoff delays are set to ~zero so tests don't actually wait.
final class RetryInterceptorTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    actor CallCounter {
        private(set) var count = 0
        func tick() -> Int {
            count += 1
            return count
        }
    }

    enum ScriptedOutcome: Sendable {
        case status(Int, headers: [String: String] = [:])
        case throwTransport(URLError.Code)
    }

    struct ScriptedInterceptor: HTTPInterceptor {
        let counter: CallCounter
        let outcomeForAttempt: @Sendable (Int) -> ScriptedOutcome

        func intercept(_ request: URLRequest, next: @Sendable (URLRequest) async throws -> HTTPExchange) async throws
            -> HTTPExchange
        {
            let attempt = await counter.tick()
            switch outcomeForAttempt(attempt) {
            case .status(let code, let headers):
                let url = request.url ?? URL(string: "https://example.com")!
                let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: headers)!
                return HTTPExchange(data: Data(), response: response)
            case .throwTransport(let code):
                throw URLError(code)
            }
        }
    }

    private func networking(_ retry: RetryInterceptor, _ scripted: ScriptedInterceptor) async -> Networking {
        let networking = Networking(baseURL: baseURL)
        await networking.setInterceptors([retry, scripted])
        return networking
    }

    func testRetriesTransientStatusThenSucceeds() async {
        let counter = CallCounter()
        let networking = await networking(
            RetryInterceptor(maxAttempts: 5, baseDelay: .milliseconds(1), maxDelay: .milliseconds(2)),
            ScriptedInterceptor(counter: counter) { $0 <= 2 ? .status(503) : .status(200) }
        )

        let result: Result<Data, NetworkingError> = await networking.get("/anything")

        if case .failure(let error) = result { XCTFail("expected success after retries, got \(error)") }
        let attempts = await counter.count
        XCTAssertEqual(attempts, 3, "two 503s should be retried, succeeding on the third attempt")
    }

    func testGivesUpAfterMaxAttempts() async {
        let counter = CallCounter()
        let networking = await networking(
            RetryInterceptor(maxAttempts: 3, baseDelay: .milliseconds(1), maxDelay: .milliseconds(2)),
            ScriptedInterceptor(counter: counter) { _ in .status(503) }
        )

        let result: Result<Data, NetworkingError> = await networking.get("/anything")

        guard case .failure(.http(let error)) = result else {
            return XCTFail("expected an HTTP failure, got \(result)")
        }
        XCTAssertEqual(error.statusCode, 503)
        let attempts = await counter.count
        XCTAssertEqual(attempts, 3, "a persistently failing request should stop at maxAttempts")
    }

    func testHonorsRetryAfterHeader() async {
        let counter = CallCounter()
        let networking = await networking(
            RetryInterceptor(maxAttempts: 3, baseDelay: .milliseconds(1), maxDelay: .seconds(5)),
            ScriptedInterceptor(counter: counter) {
                $0 == 1 ? .status(429, headers: ["Retry-After": "1"]) : .status(200)
            }
        )

        let clock = ContinuousClock()
        let start = clock.now
        let result: Result<Data, NetworkingError> = await networking.get("/anything")
        let elapsed = clock.now - start

        if case .failure(let error) = result { XCTFail("expected success after honoring Retry-After, got \(error)") }
        XCTAssertGreaterThanOrEqual(
            elapsed, .milliseconds(900), "Retry-After: 1 should pace the retry ~1s, not the 1ms base backoff")
    }

    // Retrying a non-idempotent request after a timeout/5xx can duplicate a side effect (a second charge,
    // a duplicate mutation), since the server may have processed the first attempt. POST/PATCH must not be
    // retried by default — only the idempotent methods.
    func testDoesNotRetryNonIdempotentMethodByDefault() async {
        let counter = CallCounter()
        let networking = await networking(
            RetryInterceptor(maxAttempts: 3, baseDelay: .milliseconds(1), maxDelay: .milliseconds(2)),
            ScriptedInterceptor(counter: counter) { _ in .status(503) }
        )

        let result: Result<Data, NetworkingError> = await networking.post("/anything", body: ["k": "v"])

        guard case .failure(.http(let error)) = result else {
            return XCTFail("expected an HTTP failure, got \(result)")
        }
        XCTAssertEqual(error.statusCode, 503)
        let attempts = await counter.count
        XCTAssertEqual(attempts, 1, "POST is not idempotent and must not be retried by default")
    }

    func testRetriesNonIdempotentMethodWhenExplicitlyConfigured() async {
        let counter = CallCounter()
        let networking = await networking(
            RetryInterceptor(
                maxAttempts: 3, baseDelay: .milliseconds(1), maxDelay: .milliseconds(2),
                retryableMethods: ["POST"]),
            ScriptedInterceptor(counter: counter) { _ in .status(503) }
        )

        let result: Result<Data, NetworkingError> = await networking.post("/anything", body: ["k": "v"])

        if case .success = result { XCTFail("expected the persistent 503 to fail") }
        let attempts = await counter.count
        XCTAssertEqual(attempts, 3, "an explicit retryableMethods opt-in should retry POST")
    }

    func testDoesNotRetryNonRetryableStatus() async {
        let counter = CallCounter()
        let networking = await networking(
            RetryInterceptor(maxAttempts: 3, baseDelay: .milliseconds(1), maxDelay: .milliseconds(2)),
            ScriptedInterceptor(counter: counter) { _ in .status(404) }
        )

        let result: Result<Data, NetworkingError> = await networking.get("/anything")

        guard case .failure(.http(let error)) = result else {
            return XCTFail("expected an HTTP failure, got \(result)")
        }
        XCTAssertEqual(error.statusCode, 404)
        let attempts = await counter.count
        XCTAssertEqual(attempts, 1, "a 404 is not retryable and must not be retried")
    }

    func testRetriesTransientTransportError() async {
        let counter = CallCounter()
        let networking = await networking(
            RetryInterceptor(maxAttempts: 4, baseDelay: .milliseconds(1), maxDelay: .milliseconds(2)),
            ScriptedInterceptor(counter: counter) { $0 <= 2 ? .throwTransport(.timedOut) : .status(200) }
        )

        let result: Result<Data, NetworkingError> = await networking.get("/anything")

        if case .failure(let error) = result {
            XCTFail("expected success after transient transport retries, got \(error)")
        }
        let attempts = await counter.count
        XCTAssertEqual(attempts, 3, "two timeouts should be retried, succeeding on the third attempt")
    }
}
