import Foundation
import XCTest
@testable import Networking

final class ObservabilityIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testObserverReceivesStartedThenCompletedWithMatchingID() async throws {
        let networking = Networking(baseURL: baseURL)
        let events = Box<[NetworkingEvent]>([])
        await networking.setObserver { event in events.value.append(event) }

        let _: Result<JSONResponse, NetworkingError> = await networking.get("/get")

        XCTAssertEqual(events.value.count, 2, "expected a .started and a .completed event")
        guard case let .started(startContext) = events.value.first,
              case let .completed(endContext, outcome, duration, metrics) = events.value.last else {
            return XCTFail("expected .started then .completed, got \(events.value)")
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

    func testObserverReportsFailureOutcome() async throws {
        let networking = Networking(baseURL: baseURL)
        let events = Box<[NetworkingEvent]>([])
        await networking.setObserver { event in events.value.append(event) }

        let _: Result<Data, NetworkingError> = await networking.get("/status/500")

        guard case let .completed(_, outcome, _, _) = events.value.last else {
            return XCTFail("expected a .completed event, got \(events.value)")
        }
        guard case let .failure(error) = outcome, case let .http(httpError) = error else {
            return XCTFail("expected a failure outcome carrying an HTTP error, got \(outcome)")
        }
        XCTAssertEqual(httpError.statusCode, 500)
    }

    func testObserverRedactsSensitiveHeaders() async throws {
        let networking = Networking(baseURL: baseURL)
        await networking.setAuthorizationHeader(token: "supersecret")
        await networking.setHeaderFields(["Cookie": "session=abc", "X-Trace": "trace-123"])
        let events = Box<[NetworkingEvent]>([])
        await networking.setObserver { event in events.value.append(event) }

        let _: Result<JSONResponse, NetworkingError> = await networking.get("/get")

        guard case let .started(context) = events.value.first else {
            return XCTFail("expected a .started event, got \(events.value)")
        }
        XCTAssertEqual(context.headers["Authorization"], "<redacted>")
        XCTAssertEqual(context.headers["Cookie"], "<redacted>")
        XCTAssertEqual(context.headers["X-Trace"], "trace-123", "non-sensitive headers must pass through")
    }

    // A request that fails to encode never reaches the network, but it's still a request attempt — it must
    // emit the same .started/.completed pair so observers (analytics, activity indicators) don't miss it.
    func testObserverReceivesEventsForEncodingFailure() async {
        struct Unencodable: Encodable { let value = Double.infinity } // JSONEncoder throws by default.
        let networking = Networking(baseURL: baseURL)
        let events = Box<[NetworkingEvent]>([])
        await networking.setObserver { event in events.value.append(event) }

        let _: Result<Data, NetworkingError> = await networking.post("/post", body: Unencodable())

        XCTAssertEqual(events.value.count, 2, "an encode failure must still emit .started and .completed; got \(events.value)")
        guard case let .started(startContext) = events.value.first,
              case let .completed(endContext, outcome, _, _) = events.value.last else {
            return XCTFail("expected .started then .completed, got \(events.value)")
        }
        XCTAssertEqual(startContext.id, endContext.id, "both events should share a request id")
        guard case let .failure(error) = outcome, case .invalidRequest = error else {
            return XCTFail("expected an .invalidRequest failure outcome, got \(outcome)")
        }
    }
}
