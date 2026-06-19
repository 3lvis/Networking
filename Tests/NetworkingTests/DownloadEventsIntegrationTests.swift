import Foundation
import XCTest

@testable import Networking

final class DownloadEventsIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    // Downloads are requests too — they must emit the same .started/.completed pair as the verb path.
    func testDownloadImageEmitsStartedAndCompleted() async {
        let networking = Networking(baseURL: baseURL)
        let pigImage = Image.find(named: "pig.png", inBundle: .module)
        await networking.fakeImageDownload("/image/png", image: pigImage)
        let stream = await networking.events()

        let _: Result<Image, NetworkingError> = await networking.downloadImage("/image/png")

        let events = await stream.collect(2)
        XCTAssertEqual(events.count, 2, "downloadImage should emit .started and .completed; got \(events)")
        guard case .started(let startContext) = events.first,
            case .completed(let endContext, let outcome, _, _) = events.last
        else {
            return XCTFail("expected .started then .completed, got \(events)")
        }
        XCTAssertEqual(startContext.id, endContext.id)
        guard case .success = outcome else {
            return XCTFail("expected a success outcome, got \(outcome)")
        }
    }

    func testDownloadImageEmitsFailureForBadStatus() async {
        let networking = Networking(baseURL: baseURL)
        let pigImage = Image.find(named: "pig.png", inBundle: .module)
        await networking.fakeImageDownload("/image/png", image: pigImage, statusCode: 404)
        let stream = await networking.events()

        let _: Result<Image, NetworkingError> = await networking.downloadImage("/image/png")

        let events = await stream.collect(2)
        guard case .completed(_, let outcome, _, _) = events.last else {
            return XCTFail("expected a .completed event, got \(events)")
        }
        guard case .failure(let error) = outcome, case .http = error else {
            return XCTFail("expected an HTTP failure outcome, got \(outcome)")
        }
    }
}
