import Foundation
import XCTest
@testable import Networking

class GETIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testGET() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<NetworkingResponse, NetworkingError> = await networking.get("/get")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get")
            XCTAssertNil(httpbinEchoedMap(response, "headers")["Content-Type"])
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETWithFullPath() async throws {
        let networking = Networking()
        let result: Result<NetworkingResponse, NetworkingError> = await networking.get("\(TestConfig.httpbinBaseURL)/get")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get")
            XCTAssertNil(httpbinEchoedMap(response, "headers")["Content-Type"])
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETWithHeaders() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<NetworkingResponse, NetworkingError> = await networking.get("/get")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get")
            XCTAssertTrue(response.headers.string(for: "Content-Type")?.hasPrefix("application/json") ?? false)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETWithInvalidPath() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<NetworkingResponse, NetworkingError> = await networking.get("/invalidpath")
        switch result {
        case .success:
            XCTFail()
        case let .failure(error):
            guard case let .clientError(statusCode, _) = error else {
                return XCTFail("expected a client error, got \(error)")
            }
            XCTAssertEqual(statusCode, 404)
        }
    }

    func testStatusCodes() async throws {
        let networking = Networking(baseURL: baseURL)

        // 2xx succeeds (empty body, so decode as Data).
        let ok: Result<Data, NetworkingError> = await networking.get("/status/200")
        if case let .failure(error) = ok { XCTFail("200 should succeed, got \(error)") }

        // 4xx -> clientError carrying the status code.
        let clientError: Result<Data, NetworkingError> = await networking.get("/status/404")
        guard case let .failure(.clientError(clientStatus, _)) = clientError else {
            return XCTFail("expected a client error")
        }
        XCTAssertEqual(clientStatus, 404)

        // 5xx -> serverError carrying the status code.
        let serverError: Result<Data, NetworkingError> = await networking.get("/status/500")
        guard case let .failure(.serverError(serverStatus, _, _)) = serverError else {
            return XCTFail("expected a server error")
        }
        XCTAssertEqual(serverStatus, 500)
    }

    func testGETWithURLEncodedParameters() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<NetworkingResponse, NetworkingError> = await networking.get("/get", parameters: ["count": 25])
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get?count=25")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETWithURLEncodedParametersWithExistingQuery() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<NetworkingResponse, NetworkingError> = await networking.get("/get?accountId=123", parameters: ["userId": 5])
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get?accountId=123&userId=5")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETWithURLEncodedParametersWithPercentEncoding() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<NetworkingResponse, NetworkingError> = await networking.get("/get", parameters: ["name": "Elvis Nuñez"])
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get?name=Elvis%20Nu%C3%B1ez")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    // /uuid returns a fresh value per call, so a matching second response proves the first
    // was served from cache. Also exercises the new statusCode on NetworkingResponse.
    func testGETResponseCaching() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, cache: cache)

        let first: Result<NetworkingResponse, NetworkingError> = await networking.get("/uuid", cachingLevel: .memory)
        let second: Result<NetworkingResponse, NetworkingError> = await networking.get("/uuid", cachingLevel: .memory)

        guard case let .success(firstResponse) = first, case let .success(secondResponse) = second else {
            return XCTFail("expected both requests to succeed")
        }
        XCTAssertEqual(firstResponse.statusCode, 200)
        XCTAssertNotNil(firstResponse.body.string(for: "uuid"))
        XCTAssertEqual(
            firstResponse.body.string(for: "uuid"),
            secondResponse.body.string(for: "uuid"),
            "the second request should return the cached response"
        )
    }
}
