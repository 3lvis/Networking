import Foundation
import XCTest
@testable import Networking

final class FileLoggingIntegrationTests: XCTestCase {
    // The diagnostics file sink lets a CLI / headless / agent run read what happened, since os.Logger
    // isn't visible in stdout. (The NETWORKING_LOG_FILE env var sets the same `logFileURL` at init.)
    func testDiagnosticsAreWrittenToConfiguredFile() async throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("networking-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: url) }

        let networking = Networking(baseURL: TestConfig.httpbinBaseURL)
        await networking.setLogFileURL(url)

        let _: Result<JSONResponse, NetworkingError> = await networking.get("/get")
        let _: Result<JSONResponse, NetworkingError> = await networking.get("/status/404")

        let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        XCTAssertTrue(contents.contains("→ GET /get"), "expected the request-start line; got:\n\(contents)")
        XCTAssertTrue(contents.contains("← 200"), "expected the success line; got:\n\(contents)")
        XCTAssertTrue(contents.contains("failed: The server returned status 404"), "expected the failure line; got:\n\(contents)")
    }

    // NETWORKING_LOG_FILE resolution: a bare name lands in Caches (sandbox-safe for an app); a path is used as-is.
    func testLogFileEnvValueResolution() {
        let bare = Networking.resolveLogFileURL("networking.log")
        XCTAssertEqual(bare?.lastPathComponent, "networking.log")
        XCTAssertTrue(bare?.path.contains("Caches") ?? false, "a bare name should resolve under Caches; got \(String(describing: bare?.path))")

        XCTAssertEqual(Networking.resolveLogFileURL("/tmp/explicit.log")?.path, "/tmp/explicit.log")
        XCTAssertNil(Networking.resolveLogFileURL(""))
    }
}
