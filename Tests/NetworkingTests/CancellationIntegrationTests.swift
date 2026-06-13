import Foundation
import XCTest
@testable import Networking

class CancellationIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    // Cancelling the Task running a new-API request surfaces `.cancelled`. go-httpbin's
    // `/delay/{n}` keeps the request in flight long enough to cancel it deterministically.

    func testCancelGET() async throws {
        let networking = Networking(baseURL: baseURL)
        let task = Task { () -> Result<NetworkingResponse, NetworkingError> in
            await networking.get("/delay/5")
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()
        assertCancelled(await task.value)
    }

    func testCancelPOST() async throws {
        let networking = Networking(baseURL: baseURL)
        let task = Task { () -> Result<NetworkingResponse, NetworkingError> in
            await networking.post("/delay/5", parameters: [:])
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()
        assertCancelled(await task.value)
    }

    func testCancelPUT() async throws {
        let networking = Networking(baseURL: baseURL)
        let task = Task { () -> Result<NetworkingResponse, NetworkingError> in
            await networking.put("/delay/5", parameters: [:])
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()
        assertCancelled(await task.value)
    }

    func testCancelPATCH() async throws {
        let networking = Networking(baseURL: baseURL)
        let task = Task { () -> Result<NetworkingResponse, NetworkingError> in
            await networking.patch("/delay/5", parameters: [:])
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()
        assertCancelled(await task.value)
    }

    func testCancelDELETE() async throws {
        let networking = Networking(baseURL: baseURL)
        let task = Task { () -> Result<Void, NetworkingError> in
            await networking.delete("/delay/5")
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()
        assertCancelled(await task.value)
    }

    func testCancelImageDownload() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/delay/5"
        let task = Task { () -> Result<Image, NetworkingError> in
            await networking.downloadImage(path)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        try await networking.cancelImageDownload(path)
        assertCancelled(await task.value)
    }

    func testCancelAllRequests() async throws {
        let networking = Networking(baseURL: baseURL)
        let task = Task { () -> Result<NetworkingResponse, NetworkingError> in
            await networking.get("/delay/5")
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        await networking.cancelAllRequests()
        assertCancelled(await task.value)
    }

    // Two requests to the SAME url: cancelling one Task cancels only that request, the other
    // completes. This is the precise per-request cancellation the old requestID/taskDescription
    // mechanism existed for — now provided natively by the Task handle, no extra plumbing.
    func testCancelOneOfTwoConcurrentRequestsToSameURL() async throws {
        let networking = Networking(baseURL: baseURL)
        let cancelled = Task { () -> Result<NetworkingResponse, NetworkingError> in
            await networking.get("/delay/2")
        }
        let kept = Task { () -> Result<NetworkingResponse, NetworkingError> in
            await networking.get("/delay/2")
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        cancelled.cancel()

        assertCancelled(await cancelled.value)
        switch await kept.value {
        case .success:
            break
        case .failure(let error):
            XCTFail("the un-cancelled request should have completed, got \(error)")
        }
    }

    private func assertCancelled<T>(_ result: Result<T, NetworkingError>) {
        switch result {
        case .success:
            XCTFail("expected the request to be cancelled")
        case .failure(let error):
            guard case .cancelled = error else {
                return XCTFail("expected .cancelled, got \(error)")
            }
        }
    }
}
