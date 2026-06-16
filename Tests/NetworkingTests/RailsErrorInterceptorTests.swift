import Foundation
import XCTest
@testable import Networking

// A scripted innermost interceptor returns a canned (status, body) without hitting the network, so the
// RailsErrorInterceptor's parsing is exercised deterministically and offline.
final class RailsErrorInterceptorTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    actor CallCounter {
        private(set) var count = 0
        func tick() { count += 1 }
    }

    struct Responder: HTTPInterceptor {
        let statusCode: Int
        let body: Data
        var counter: CallCounter?

        func intercept(_ request: URLRequest, next: @Sendable (URLRequest) async throws -> HTTPExchange) async throws -> HTTPExchange {
            await counter?.tick()
            let url = request.url ?? URL(string: "https://example.com")!
            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            return HTTPExchange(data: body, response: response)
        }
    }

    // RailsErrorInterceptor is registered outermost (per its contract); `inner` interceptors sit between
    // it and the scripted responder.
    private func networking(status: Int, body: String, counter: CallCounter? = nil, inner: [HTTPInterceptor] = []) async -> Networking {
        let networking = Networking(baseURL: baseURL)
        let responder = Responder(statusCode: status, body: Data(body.utf8), counter: counter)
        await networking.setInterceptors([RailsErrorInterceptor()] + inner + [responder])
        return networking
    }

    private func serverMessage(_ result: Result<Data, NetworkingError>, line: UInt = #line) -> String? {
        guard case let .failure(.http(error)) = result else {
            XCTFail("expected an .http failure, got \(result)", line: line)
            return nil
        }
        return error.serverMessage
    }

    func testFlatActiveModelErrors() async {
        let networking = await networking(status: 422, body: #"{"errors":{"start_time":["Start time can't be blank"]}}"#)
        let message = serverMessage(await networking.get("/anything"))
        XCTAssertEqual(message, "Start time can't be blank")
    }

    func testBaseRecordLevelError() async {
        let networking = await networking(status: 422, body: #"{"errors":{"base":["Availability duration must be at least 240 minutes."]}}"#)
        let message = serverMessage(await networking.get("/anything"))
        XCTAssertEqual(message, "Availability duration must be at least 240 minutes.")
    }

    // The grouped/nested shape the flat core `ErrorResponse` can't decode — the case that motivated moving
    // full-shape parsing into this interceptor.
    func testNestedGroupedErrors() async {
        let networking = await networking(status: 422, body: #"{"errors":{"validation":{"start_time":["Start time can't be blank"]},"authentication":["Invalid token"]}}"#)
        let message = serverMessage(await networking.get("/anything"))
        XCTAssertTrue(message?.contains("Start time can't be blank") == true, "got \(message ?? "nil")")
        XCTAssertTrue(message?.contains("Invalid token") == true, "got \(message ?? "nil")")
    }

    func testJSONAPIErrorsArray() async {
        let networking = await networking(status: 422, body: #"{"errors":[{"status":"422","detail":"Start time can't be blank"},{"status":"422","detail":"End time can't be blank"}]}"#)
        let message = serverMessage(await networking.get("/anything"))
        XCTAssertEqual(message, "Start time can't be blank; End time can't be blank", "JSON:API array order is preserved")
    }

    func testTopLevelMessage() async {
        let networking = await networking(status: 404, body: #"{"message":"Resource not found"}"#)
        let message = serverMessage(await networking.get("/anything"))
        XCTAssertEqual(message, "Resource not found")
    }

    // A body the interceptor doesn't recognize is passed through untouched: still an .http error with the
    // status code, just no interceptor-shaped message.
    func testUnrecognizedBodyPassesThrough() async {
        let networking = await networking(status: 500, body: #"{"detail":"boom"}"#)
        guard case let .failure(.http(error)) = await networking.get("/anything") as Result<Data, NetworkingError> else {
            return XCTFail("expected an .http failure")
        }
        XCTAssertEqual(error.statusCode, 500)
        XCTAssertNil(error.serverMessage, "an unrecognized body must not be given a fabricated message")
    }

    // A 2xx is a success even with an `errors`-shaped body — the interceptor only scrutinizes failures.
    func testSuccessPassesThrough() async {
        let networking = await networking(status: 200, body: #"{"errors":{"base":["ignored on success"]}}"#)
        let result: Result<Data, NetworkingError> = await networking.get("/anything")
        if case let .failure(error) = result { XCTFail("expected success, got \(error)") }
    }

    // Registered outermost, it shapes the error only after RetryInterceptor (inner) has exhausted its
    // retries on the transient 503.
    func testComposesWithRetryOutermost() async {
        let counter = CallCounter()
        let retry = RetryInterceptor(maxAttempts: 3, baseDelay: .milliseconds(1), maxDelay: .milliseconds(2))
        let networking = await networking(
            status: 503,
            body: #"{"errors":{"base":["Service temporarily unavailable"]}}"#,
            counter: counter,
            inner: [retry]
        )
        let message = serverMessage(await networking.get("/anything"))
        XCTAssertEqual(message, "Service temporarily unavailable")
        let attempts = await counter.count
        XCTAssertEqual(attempts, 3, "retry runs underneath; the Rails interceptor shapes the final attempt")
    }
}
