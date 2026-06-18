import Foundation
import XCTest
@testable import Networking

class NetworkingTests: XCTestCase {
    let baseURL = "http://example.com"

    func setAuthorizationHeaderCustomValue() async throws {
        let networking = Networking(baseURL: baseURL)
        let value = "hi-mom"
        await networking.setAuthorizationHeader(headerValue: value)
        let result: Result<JSONResponse, NetworkingError> = await networking.post("/post")
        switch result {
        case let .success(response):
            let headers = httpbinEchoedMap(response, "headers")
            XCTAssertEqual(value, headers["Authorization"])
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func setAuthorizationHeaderCustomHeaderKeyAndValue() async throws {
        let networking = Networking(baseURL: baseURL)
        let key = "Anonymous-Token"
        let value = "hi-mom"
        await networking.setAuthorizationHeader(headerKey: key, headerValue: value)
        let result: Result<JSONResponse, NetworkingError> = await networking.post("/post")
        switch result {
        case let .success(response):
            let headers = httpbinEchoedMap(response, "headers")
            XCTAssertEqual(value, headers[key])
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testURLForPath() throws {
        let networking = Networking(baseURL: baseURL)
        let url = try networking.composedURL(with: "/hello")
        XCTAssertEqual(url.absoluteString, "http://example.com/hello")
    }

    func testURLForPathWithFullPath() throws {
        let networking = Networking()
        let url = try networking.composedURL(with: "http://example.com/hello")
        XCTAssertEqual(url.absoluteString, "http://example.com/hello")
    }

    func testDestinationURL() throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let destinationURL = try networking.destinationURL(for: path)
        XCTAssertEqual(destinationURL.lastPathComponent, "http:--example.com-image-png")
    }

    func testDestinationURLWithFullPath() throws {
        let networking = Networking()
        let path = "http://example.com/image/png"
        let destinationURL = try networking.destinationURL(for: path)
        XCTAssertEqual(destinationURL.lastPathComponent, "http:--example.com-image-png")
    }

    func testDestinationURLWithSpecialCharactersInPath() throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/h�sttur.jpg"
        let destinationURL = try networking.destinationURL(for: path)
        XCTAssertEqual(destinationURL.lastPathComponent, "http:--example.com-h%EF%BF%BDsttur.jpg")
    }

    func testDestinationURLWithSpecialCharactersInCacheName() throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/the-url-doesnt-really-matter"
        let destinationURL = try networking.destinationURL(for: path, cacheName: "h�sttur.jpg-25-03/small")
        XCTAssertEqual(destinationURL.lastPathComponent, "h%EF%BF%BDsttur.jpg-25-03-small")
    }

    func testDestinationURLCache() throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "png/png"
        let destinationURL = try networking.destinationURL(for: path, cacheName: cacheName)
        XCTAssertEqual(destinationURL.lastPathComponent, "png-png")
    }

    // The clock is the file's modification date: fresh is warm, older-than-TTL is cold, no date is kept.
    func testCacheExpiryUsesFileDate() {
        let expiry = CacheExpiry(ttl: .seconds(60))
        XCTAssertFalse(expiry.isExpired(fileDate: Date()))
        XCTAssertTrue(expiry.isExpired(fileDate: Date(timeIntervalSinceNow: -120)))
        XCTAssertFalse(expiry.isExpired(fileDate: nil), "unknown age is kept, not expired")
    }

    // Cache files live under a one-hex-nibble shard directory so the per-launch sweep is O(N / shardCount).
    func testCacheFilesAreSharded() throws {
        let networking = Networking(baseURL: baseURL)
        let url = try networking.destinationURL(for: "/image/png")
        let shard = url.deletingLastPathComponent().lastPathComponent
        XCTAssertEqual(shard.count, 1)
        XCTAssertTrue(shard.allSatisfy { $0.isHexDigit })
        XCTAssertEqual(url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent, Networking.domain)
    }

    func testStatusCodeType() {
        typealias StatusCodeType = Networking.StatusCodeType
        XCTAssertEqual(StatusCodeType(statusCode: URLError.cancelled.rawValue), .cancelled)
        XCTAssertEqual(StatusCodeType(statusCode: 99), .unknown)
        XCTAssertEqual(StatusCodeType(statusCode: 100), .informational)
        XCTAssertEqual(StatusCodeType(statusCode: 199), .informational)
        XCTAssertEqual(StatusCodeType(statusCode: 200), .successful)
        XCTAssertEqual(StatusCodeType(statusCode: 299), .successful)
        XCTAssertEqual(StatusCodeType(statusCode: 300), .redirection)
        XCTAssertEqual(StatusCodeType(statusCode: 399), .redirection)
        XCTAssertEqual(StatusCodeType(statusCode: 400), .clientError)
        XCTAssertEqual(StatusCodeType(statusCode: 499), .clientError)
        XCTAssertEqual(StatusCodeType(statusCode: 500), .serverError)
        XCTAssertEqual(StatusCodeType(statusCode: 599), .serverError)
        XCTAssertEqual(StatusCodeType(statusCode: 600), .unknown)
    }

    func testSplitBaseURLAndRelativePath() throws {
        let (baseURL1, relativePath1) = try XCTUnwrap(Networking.splitBaseURLAndRelativePath(for: "https://rescuejuice.com/wp-content/uploads/2015/11/døgnvillburgere.jpg"))
        XCTAssertEqual(baseURL1, "https://rescuejuice.com")
        XCTAssertEqual(relativePath1, "/wp-content/uploads/2015/11/døgnvillburgere.jpg")

        let (baseURL2, relativePath2) = try XCTUnwrap(Networking.splitBaseURLAndRelativePath(for: "http://example.com/basic-auth/user/passwd"))
        XCTAssertEqual(baseURL2, "http://example.com")
        XCTAssertEqual(relativePath2, "/basic-auth/user/passwd")
    }

    func testReset() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.setAuthorizationHeader(username: "user", password: "passwd")
        await networking.setAuthorizationHeader(token: "token")
        await networking.setHeaderFields(["HeaderKey": "HeaderValue"])

        var token = await networking.token
        var authKey = await networking.authorizationHeaderKey
        var authValue = await networking.authorizationHeaderValue
        XCTAssertEqual(token, "token")
        XCTAssertEqual(authKey, "Authorization")
        XCTAssertEqual(authValue, "Basic dXNlcjpwYXNzd2Q=")

        try await networking.reset()

        token = await networking.token
        authKey = await networking.authorizationHeaderKey
        authValue = await networking.authorizationHeaderValue
        XCTAssertNil(token)
        XCTAssertEqual(authKey, "Authorization")
        XCTAssertNil(authValue)
    }
}
