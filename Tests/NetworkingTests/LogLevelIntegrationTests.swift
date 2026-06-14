import Foundation
import XCTest
@testable import Networking

final class LogLevelIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    private func tempLogURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("networking-\(UUID().uuidString).log")
    }

    // .body is the most verbose level: it logs redacted headers and truncated request/response bodies.
    func testBodyLevelLogsHeadersAndBodies() async throws {
        let url = tempLogURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let networking = Networking(baseURL: baseURL)
        await networking.setLogFileURL(url)
        await networking.setLogLevel(.body)

        let _: Result<JSONResponse, NetworkingError> = await networking.post("/post", body: ["hello": "world"])

        let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        XCTAssertTrue(contents.contains("→ body:"), "expected the request body at .body; got:\n\(contents)")
        XCTAssertTrue(contents.contains("← body:"), "expected the response body at .body; got:\n\(contents)")
        XCTAssertTrue(contents.contains("Content-Type"), "expected headers at .body; got:\n\(contents)")
    }

    // .none silences the built-in diagnostics entirely (the observer/stream still fire).
    func testNoneLevelSilences() async throws {
        let url = tempLogURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let networking = Networking(baseURL: baseURL)
        await networking.setLogFileURL(url)
        await networking.setLogLevel(.none)

        let _: Result<JSONResponse, NetworkingError> = await networking.get("/get")

        let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        XCTAssertTrue(contents.isEmpty, "no diagnostics should be written at .none; got:\n\(contents)")
    }

    // .basic (default) logs the request/response lines but neither headers nor bodies.
    func testBasicLevelOmitsHeadersAndBodies() async throws {
        let url = tempLogURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let networking = Networking(baseURL: baseURL)
        await networking.setLogFileURL(url)
        await networking.setLogLevel(.basic)

        let _: Result<JSONResponse, NetworkingError> = await networking.post("/post", body: ["hello": "world"])

        let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        XCTAssertTrue(contents.contains("→ POST /post"), "expected the basic request line; got:\n\(contents)")
        XCTAssertFalse(contents.contains("→ body:"), "must not log bodies at .basic; got:\n\(contents)")
        XCTAssertFalse(contents.contains("Content-Type"), "must not log headers at .basic; got:\n\(contents)")
    }
}
