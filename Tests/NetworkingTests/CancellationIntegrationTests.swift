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
        let task = Task { try await networking.downloadImage("/delay/5") }
        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("expected the download to be cancelled")
        } catch {
            let isCancellation = error is CancellationError || (error as? URLError)?.code == .cancelled
            XCTAssertTrue(isCancellation, "expected a cancellation error, got \(error)")
        }
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
