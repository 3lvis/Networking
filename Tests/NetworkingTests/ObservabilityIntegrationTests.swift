import Foundation
import XCTest
@testable import Networking

final class ObservabilityIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testStreamReceivesStartedThenCompletedWithMatchingID() async throws {
        let networking = Networking(baseURL: baseURL)
        let stream = await networking.events()

        let _: Result<JSONResponse, NetworkingError> = await networking.get("/get")

        let events = await stream.collect(2)
        XCTAssertEqual(events.count, 2, "expected a .started and a .completed event")
        guard case let .started(startContext) = events.first,
              case let .completed(endContext, outcome, duration, metrics) = events.last else {
            return XCTFail("expected .started then .completed, got \(events)")
        }
        XCTAssertEqual(startContext.id, endContext.id, "the two events should share a request id")
        XCTAssertEqual(startContext.method, "GET")
        XCTAssertGreaterThan(duration, .zero)
        guard case let .success(statusCode, byteCount) = outcome else {
            return XCTFail("expected a success outcome, got \(outcome)")
        }
        XCTAssertEqual(statusCode, 200)
        XCTAssertGreaterThan(byteCount, 0)
        XCTAssertNotNil(metrics, "a real network request should carry URLSessionTaskMetrics")
    }

    func testStreamReportsFailureOutcome() async throws {
        let networking = Networking(baseURL: baseURL)
        let stream = await networking.events()

        let _: Result<Data, NetworkingError> = await networking.get("/status/500")

        let events = await stream.collect(2)
        guard case let .completed(_, outcome, _, _) = events.last else {
            return XCTFail("expected a .completed event, got \(events)")
        }
        guard case let .failure(error) = outcome, case let .http(httpError) = error else {
            return XCTFail("expected a failure outcome carrying an HTTP error, got \(outcome)")
        }
        XCTAssertEqual(httpError.statusCode, 500)
    }

    // events() is your own request data — it carries raw headers (redaction is a logging concern, not an
    // observation one). The built-in *logs* redact sensitive headers in release builds (see LogLevel tests).
    func testStartedEventCarriesRawHeaders() async throws {
        let networking = Networking(baseURL: baseURL)
        await networking.setAuthorizationHeader(token: "supersecret")
        await networking.setHeaderFields(["Cookie": "session=abc", "X-Trace": "trace-123"])
        let stream = await networking.events()

        let _: Result<JSONResponse, NetworkingError> = await networking.get("/get")

        let events = await stream.collect(1)
        guard case let .started(context) = events.first else {
            return XCTFail("expected a .started event, got \(events)")
        }
        XCTAssertEqual(context.headers["Authorization"], "Bearer supersecret", "events() carries the real header value")
        XCTAssertEqual(context.headers["Cookie"], "session=abc")
        XCTAssertEqual(context.headers["X-Trace"], "trace-123")
    }

    // A request that fails to encode never reaches the network, but it's still a request attempt — it must
    // emit the same .started/.completed pair so consumers (analytics, activity indicators) don't miss it.
    func testEncodingFailureStillEmitsEvents() async {
        struct Unencodable: Encodable { let value = Double.infinity } // JSONEncoder throws by default.
        let networking = Networking(baseURL: baseURL)
        let stream = await networking.events()

        let _: Result<Data, NetworkingError> = await networking.post("/post", body: Unencodable())

        let events = await stream.collect(2)
        XCTAssertEqual(events.count, 2, "an encode failure must still emit .started and .completed; got \(events)")
        guard case let .started(startContext) = events.first,
              case let .completed(endContext, outcome, _, _) = events.last else {
            return XCTFail("expected .started then .completed, got \(events)")
        }
        XCTAssertEqual(startContext.id, endContext.id, "both events should share a request id")
        guard case let .failure(error) = outcome, case .invalidRequest = error else {
            return XCTFail("expected an .invalidRequest failure outcome, got \(outcome)")
        }
    }
}
