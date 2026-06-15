import Foundation
import XCTest
@testable import Networking

// go-httpbin's /xml returns 200 with application/xml and /json returns 200 with application/json, so a
// content-type validator can be exercised against real responses.
final class ResponseValidatorIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    private func requireJSON(_ networking: Networking) async {
        await networking.setInterceptors([
            ResponseValidatorInterceptor { exchange in
                let contentType = exchange.response.value(forHTTPHeaderField: "Content-Type") ?? ""
                return contentType.hasPrefix("application/json")
                    ? .valid
                    : .invalid(reason: "expected application/json, got \(contentType)")
            }
        ])
    }

    func testRejectsResponseFailingValidation() async {
        let networking = Networking(baseURL: baseURL)
        await requireJSON(networking)

        let result: Result<Data, NetworkingError> = await networking.get("/xml")

        guard case let .failure(.validation(reason, metadata)) = result else {
            return XCTFail("expected a .validation failure, got \(result)")
        }
        XCTAssertTrue(reason.contains("application/json"), "the reason should explain the expectation; got \(reason)")
        XCTAssertEqual(metadata.statusCode, 200, "validation carries the offending response's metadata")
    }

    // A validator scrutinizes successes, not errors: a non-2xx response must still surface as its .http
    // error, never be relabeled a validation failure.
    func testNonSuccessResponseSkipsValidation() async {
        let networking = Networking(baseURL: baseURL)
        await networking.setInterceptors([
            ResponseValidatorInterceptor { _ in .invalid(reason: "rejects everything") }
        ])

        let result: Result<Data, NetworkingError> = await networking.get("/status/500")

        guard case let .failure(.http(error)) = result else { return XCTFail("expected an .http failure, got \(result)") }
        XCTAssertEqual(error.statusCode, 500)
    }

    // A cache hit is still a response the caller receives, so a validator must see it too — otherwise a
    // response cached before the validator existed (or under a different config) bypasses the check.
    func testValidatorRunsOnCacheHits() async {
        let networking = Networking(baseURL: baseURL)

        // Prime the cache with no validator installed: /xml (200, application/xml) gets stored.
        let primed: Result<Data, NetworkingError> = await networking.get("/xml", cachingLevel: .memory)
        if case let .failure(error) = primed { return XCTFail("priming the cache should succeed, got \(error)") }

        await requireJSON(networking)
        // Same request → a cache hit → must still run the JSON validator and be rejected.
        let result: Result<Data, NetworkingError> = await networking.get("/xml", cachingLevel: .memory)

        guard case .failure(.validation) = result else {
            return XCTFail("a cached response must still be validated, got \(result)")
        }
    }

    func testAcceptsValidResponse() async {
        let networking = Networking(baseURL: baseURL)
        await requireJSON(networking)

        let result: Result<JSONResponse, NetworkingError> = await networking.get("/json")

        if case let .failure(error) = result { XCTFail("expected the JSON response to pass validation, got \(error)") }
    }
}
