import Foundation
import XCTest

@testable import Networking

class GETIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testGET() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.get("/get")
        switch result {
        case .success(let response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get")
            XCTAssertNil(httpbinEchoedMap(response, "headers")["Content-Type"])
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETWithFullPath() async throws {
        let networking = Networking()
        let result: Result<JSONResponse, NetworkingError> = await networking.get("\(TestConfig.httpbinBaseURL)/get")
        switch result {
        case .success(let response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get")
            XCTAssertNil(httpbinEchoedMap(response, "headers")["Content-Type"])
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETWithHeaders() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.get("/get")
        switch result {
        case .success(let response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get")
            XCTAssertTrue(response.headers.string(for: "Content-Type")?.hasPrefix("application/json") ?? false)
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETWithInvalidPath() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.get("/invalidpath")
        switch result {
        case .success:
            XCTFail()
        case .failure(let error):
            guard case .http(let httpError) = error else {
                return XCTFail("expected an HTTP error, got \(error)")
            }
            XCTAssertEqual(httpError.statusCode, 404)
        }
    }

    func testStatusCodes() async throws {
        let networking = Networking(baseURL: baseURL)

        // 2xx succeeds (empty body, so decode as Data).
        let ok: Result<Data, NetworkingError> = await networking.get("/status/200")
        if case .failure(let error) = ok { XCTFail("200 should succeed, got \(error)") }

        // 4xx -> .http carrying the status code, flagged as a client error.
        let clientError: Result<Data, NetworkingError> = await networking.get("/status/404")
        guard case .failure(.http(let clientHTTPError)) = clientError else {
            return XCTFail("expected an HTTP error")
        }
        XCTAssertEqual(clientHTTPError.statusCode, 404)
        XCTAssertTrue(clientHTTPError.isClientError)

        // 5xx -> .http carrying the status code, flagged as a server error.
        let serverError: Result<Data, NetworkingError> = await networking.get("/status/500")
        guard case .failure(.http(let serverHTTPError)) = serverError else {
            return XCTFail("expected a server error")
        }
        XCTAssertEqual(serverHTTPError.statusCode, 500)
        XCTAssertTrue(serverHTTPError.isServerError)
    }

    func testGETWithURLEncodedParameters() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.get(
            "/get", query: [URLQueryItem(name: "count", value: "25")])
        switch result {
        case .success(let response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get?count=25")
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETWithURLEncodedParametersWithExistingQuery() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.get(
            "/get?accountId=123", query: [URLQueryItem(name: "userId", value: "5")])
        switch result {
        case .success(let response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get?accountId=123&userId=5")
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETWithURLEncodedParametersWithPercentEncoding() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.get(
            "/get", query: [URLQueryItem(name: "name", value: "Elvis Nuñez")])
        switch result {
        case .success(let response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get?name=Elvis%20Nu%C3%B1ez")
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }

    // /uuid returns a fresh value per call, so a matching second response proves the first
    // was served from cache.
    func testGETResponseCaching() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, cache: cache)

        let first: Result<JSONResponse, NetworkingError> = await networking.get("/uuid", cachingLevel: .memory)
        let second: Result<JSONResponse, NetworkingError> = await networking.get("/uuid", cachingLevel: .memory)

        guard case .success(let firstResponse) = first, case .success(let secondResponse) = second else {
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

    // `.none` is the default for `get`, so it must *bypass* the cache, never purge it — otherwise a plain
    // `get(path)` would wipe an entry deliberately cached with `.memoryAndFile`. /uuid (fresh per call)
    // proves the primed entry survives the `.none` request.
    func testNoneCachingLevelDoesNotPurgeAnExistingEntry() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, cache: cache)

        let primed: Result<JSONResponse, NetworkingError> = await networking.get("/uuid", cachingLevel: .memoryAndFile)
        let _: Result<JSONResponse, NetworkingError> = await networking.get("/uuid", cachingLevel: .none)
        let afterwards: Result<JSONResponse, NetworkingError> = await networking.get(
            "/uuid", cachingLevel: .memoryAndFile)

        guard case .success(let primedResponse) = primed, case .success(let afterwardsResponse) = afterwards else {
            return XCTFail("expected both cached requests to succeed")
        }
        XCTAssertNotNil(primedResponse.body.string(for: "uuid"))
        XCTAssertEqual(
            primedResponse.body.string(for: "uuid"),
            afterwardsResponse.body.string(for: "uuid"),
            "the .none request must not have purged the primed cache entry"
        )
    }

    // Different query parameters on the same path must not share a cache entry.
    func testGETCacheKeyIncludesParameters() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, cache: cache)

        let first: Result<JSONResponse, NetworkingError> = await networking.get(
            "/get", query: [URLQueryItem(name: "value", value: "1")], cachingLevel: .memory)
        let second: Result<JSONResponse, NetworkingError> = await networking.get(
            "/get", query: [URLQueryItem(name: "value", value: "2")], cachingLevel: .memory)

        guard case .success(let firstResponse) = first, case .success(let secondResponse) = second else {
            return XCTFail("expected both requests to succeed")
        }
        XCTAssertEqual(firstResponse.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get?value=1")
        XCTAssertEqual(secondResponse.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get?value=2")
    }

    // Two requests that differ only by parameter encoding must not collide. A naive key built by
    // raw "key=value" interpolation collapses ["a": "1&b=2"] and ["a": 1, "b": 2] to the same
    // string, even though their real URLs differ (a=1%26b%3D2 vs a=1&b=2).
    func testGETCacheKeyDistinguishesEncodedParameters() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, cache: cache)

        let _: Result<JSONResponse, NetworkingError> = await networking.get(
            "/get", query: [URLQueryItem(name: "a", value: "1&b=2")], cachingLevel: .memory)
        let second: Result<JSONResponse, NetworkingError> = await networking.get(
            "/get", query: [URLQueryItem(name: "a", value: "1"), URLQueryItem(name: "b", value: "2")],
            cachingLevel: .memory)

        guard case .success(let secondResponse) = second else {
            return XCTFail("expected the second request to succeed")
        }
        let url = secondResponse.body.string(for: "url") ?? ""
        XCTAssertFalse(url.contains("%26"), "the second request must not be served the first request's cached body")
        XCTAssertTrue(
            url.contains("a=1") && url.contains("b=2"),
            "the second request must reflect its own parameters, got: \(url)")
    }

    // Full-URL GETs to different hosts but the same path must not collide. A key built from only
    // path + query drops the host, so a second host could be served the first host's cached body.
    func testGETCacheKeyDistinguishesHost() async throws {
        let base = TestConfig.httpbinBaseURL
        let aliasHost: String
        let alias: String
        if base.contains("127.0.0.1") {
            aliasHost = "localhost"
            alias = base.replacingOccurrences(of: "127.0.0.1", with: "localhost")
        } else if base.contains("localhost") {
            aliasHost = "127.0.0.1"
            alias = base.replacingOccurrences(of: "localhost", with: "127.0.0.1")
        } else {
            throw XCTSkip("needs a host with a local alias (127.0.0.1/localhost)")
        }

        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(cache: cache)

        let _: Result<JSONResponse, NetworkingError> = await networking.get("\(base)/get", cachingLevel: .memory)
        let second: Result<JSONResponse, NetworkingError> = await networking.get("\(alias)/get", cachingLevel: .memory)

        guard case .success(let secondResponse) = second else {
            return XCTFail("expected the second request to succeed")
        }
        let url = secondResponse.body.string(for: "url") ?? ""
        XCTAssertTrue(
            url.contains(aliasHost),
            "a request to a different host must not receive the first host's cached body, got: \(url)")
    }

    // A cache hit must carry the original response's status code and headers, not fabricated ones.
    func testGETCachePreservesResponseMetadata() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, cache: cache)

        let _: Result<JSONResponse, NetworkingError> = await networking.get("/get", cachingLevel: .memory)
        let cached: Result<JSONResponse, NetworkingError> = await networking.get("/get", cachingLevel: .memory)

        guard case .success(let response) = cached else {
            return XCTFail("expected the cached request to succeed")
        }
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertTrue(response.headers.string(for: "Content-Type")?.hasPrefix("application/json") ?? false)
    }
}
