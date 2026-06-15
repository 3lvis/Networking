import Foundation
import XCTest
@testable import Networking

// Built-in logging scope: `.none` logs nothing, `.failures` (default) logs every failure with full
// detail, `.all` also logs successes with full detail. Asserted via the file sink.
final class LogLevelIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    private func log(level: Networking.LogLevel, _ body: (Networking) async -> Void) async -> String {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("networking-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: url) }
        let networking = Networking(baseURL: baseURL)
        await networking.setLogFileURL(url)
        await networking.setLogLevel(level)
        await body(networking)
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    func testFailuresLevelDoesNotLogSuccesses() async {
        let contents = await log(level: .failures) { networking in
            let _: Result<JSONResponse, NetworkingError> = await networking.get("/get")
        }
        XCTAssertTrue(contents.isEmpty, "a successful request must not be logged at .failures; got:\n\(contents)")
    }

    func testFailuresLevelLogsFailureWithFullDetail() async {
        let contents = await log(level: .failures) { networking in
            let _: Result<JSONResponse, NetworkingError> = await networking.post("/status/400", body: ["shape": "wrong"])
        }
        XCTAssertTrue(contents.contains("✗ POST"), "expected the failure line; got:\n\(contents)")
        XCTAssertTrue(contents.contains("→ Content-Type"), "expected request headers; got:\n\(contents)")
        XCTAssertTrue(contents.contains("→ body:") && contents.contains("shape"), "expected the request body; got:\n\(contents)")
        XCTAssertTrue(contents.contains("← Content-Type"), "expected response headers; got:\n\(contents)")
    }

    func testAllLevelLogsSuccessesWithFullDetail() async {
        let contents = await log(level: .all) { networking in
            let _: Result<JSONResponse, NetworkingError> = await networking.post("/post", body: ["shape": "right"])
        }
        XCTAssertTrue(contents.contains("✓ POST"), "expected a success line at .all; got:\n\(contents)")
        XCTAssertTrue(contents.contains("→ body:") && contents.contains("shape"), "expected the request body; got:\n\(contents)")
        XCTAssertTrue(contents.contains("← body:"), "expected the response body; got:\n\(contents)")
    }

    // Bodies and sensitive headers are redacted when `redactsLogs` is on (the default in release builds) —
    // the line still logs, but the payload and Authorization/Cookie values are replaced with <redacted> so
    // they can't leak to prod logs.
    func testBodiesAndHeadersRedactedWhenEnabled() async {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("networking-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: url) }
        let networking = Networking(baseURL: baseURL)
        await networking.setLogFileURL(url)
        await networking.setLogLevel(.failures)
        await networking.setRedactsLogs(true)
        await networking.setAuthorizationHeader(token: "supersecret")

        let _: Result<JSONResponse, NetworkingError> = await networking.post("/status/400", body: ["shape": "secret-value"])

        let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        XCTAssertTrue(contents.contains("✗ POST"), "the failure line should still log; got:\n\(contents)")
        XCTAssertTrue(contents.contains("→ body: <redacted>"), "the request body should be redacted; got:\n\(contents)")
        XCTAssertTrue(contents.contains("→ Authorization: <redacted>"), "the auth header should be redacted; got:\n\(contents)")
        XCTAssertFalse(contents.contains("secret-value"), "the body contents must not leak; got:\n\(contents)")
        XCTAssertFalse(contents.contains("supersecret"), "the auth token must not leak; got:\n\(contents)")
    }

    // In debug builds (redaction off by default) the log shows real header values — you're debugging, so
    // "is my Authorization header actually set?" must be answerable from the log.
    func testLogShowsRawHeadersWhenNotRedacting() async {
        let contents = await log(level: .failures) { networking in
            await networking.setAuthorizationHeader(token: "supersecret")
            let _: Result<JSONResponse, NetworkingError> = await networking.get("/status/401")
        }
        XCTAssertTrue(contents.contains("→ Authorization: Bearer supersecret"), "debug logs should show the real header; got:\n\(contents)")
    }

    func testNoneSilencesEvenFailures() async {
        let contents = await log(level: .none) { networking in
            let _: Result<JSONResponse, NetworkingError> = await networking.get("/status/500")
        }
        XCTAssertTrue(contents.isEmpty, "nothing should be logged at .none; got:\n\(contents)")
    }
}
