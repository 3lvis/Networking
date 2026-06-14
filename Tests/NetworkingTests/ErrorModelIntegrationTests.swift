import Foundation
import XCTest
@testable import Networking

final class ErrorModelIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    // A 5xx is an HTTP error that's worth retrying; a 4xx (other than 408/429) is not.
    func testRetryableServerErrorVsClientError() async throws {
        let networking = Networking(baseURL: baseURL)

        let serverResult: Result<Data, NetworkingError> = await networking.get("/status/503")
        guard case let .failure(serverError) = serverResult, case .http = serverError else {
            return XCTFail("expected an HTTP error for 503")
        }
        XCTAssertTrue(serverError.isRetryable, "503 should be retryable")
        XCTAssertEqual(serverError.statusCode, 503)

        let clientResult: Result<Data, NetworkingError> = await networking.get("/status/404")
        guard case let .failure(clientError) = clientResult, case .http = clientError else {
            return XCTFail("expected an HTTP error for 404")
        }
        XCTAssertFalse(clientError.isRetryable, "404 should not be retryable")
    }

    // A connection to a closed port never reaches a server: a transport failure carrying the URLError, and retryable.
    func testTransportErrorIsRetryable() async throws {
        let networking = Networking(baseURL: "http://127.0.0.1:1")
        let result: Result<Data, NetworkingError> = await networking.get("/anything")
        guard case let .failure(error) = result, case let .transport(urlError) = error else {
            return XCTFail("expected a transport error, got \(result)")
        }
        XCTAssertTrue(error.isRetryable, "a connection failure should be retryable")
        XCTAssertNotEqual(urlError.code, .cancelled)
    }

    // A 2xx whose body doesn't match the requested type surfaces as .decoding, with the DecodingError and
    // response metadata preserved — and is not retryable.
    func testDecodingErrorCarriesMetadata() async throws {
        struct Mismatch: Decodable { let args: Int } // httpbin's /get returns `args` as an object, not an Int.
        let networking = Networking(baseURL: baseURL)
        let result: Result<Mismatch, NetworkingError> = await networking.get("/get")
        guard case let .failure(error) = result, case let .decoding(_, metadata) = error else {
            return XCTFail("expected a decoding error, got \(result)")
        }
        XCTAssertEqual(metadata.statusCode, 200)
        XCTAssertNotNil(metadata.bodySnippet)
        XCTAssertFalse(error.isRetryable, "decoding failures should not be retryable")
    }

    // A body that can't be JSON-encoded is a caller-side bug: .invalidRequest, never sent.
    func testUnencodableBodyIsInvalidRequest() async throws {
        struct Unencodable: Encodable { let value = Double.infinity } // JSONEncoder throws by default.
        let networking = Networking(baseURL: baseURL)
        let result: Result<Data, NetworkingError> = await networking.post("/post", body: Unencodable())
        guard case let .failure(error) = result, case let .invalidRequest(reason) = error else {
            return XCTFail("expected an invalid-request error, got \(result)")
        }
        guard case .bodyEncodingFailed = reason else {
            return XCTFail("expected a body-encoding reason, got \(reason)")
        }
        XCTAssertFalse(error.isRetryable)
    }
}
