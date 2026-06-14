import Foundation
import XCTest
@testable import Networking

final class EventStreamIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    // The AsyncStream observer: accumulate events into a plain local array via `for await` — no Box,
    // no @unchecked, no @Sendable-closure capture dance.
    func testEventsStreamDeliversStartedAndCompleted() async throws {
        let networking = Networking(baseURL: baseURL)
        let stream = await networking.events()   // registered before the request, so it buffers the events

        let _: Result<JSONResponse, NetworkingError> = await networking.get("/get")

        var collected: [NetworkingEvent] = []
        for await event in stream {
            collected.append(event)
            if collected.count == 2 { break }    // .started + .completed; break so the loop ends
        }

        XCTAssertEqual(collected.count, 2)
        guard case .started = collected.first, case let .completed(_, outcome, _, _) = collected.last else {
            return XCTFail("expected .started then .completed, got \(collected)")
        }
        guard case let .success(statusCode, _) = outcome else {
            return XCTFail("expected a success outcome, got \(outcome)")
        }
        XCTAssertEqual(statusCode, 200)
    }
}
