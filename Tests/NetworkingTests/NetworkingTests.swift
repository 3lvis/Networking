import Foundation
import XCTest
@testable import Networking

class NetworkingTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func setAuthorizationHeaderCustomValue() async throws {
        let networking = Networking(baseURL: baseURL)
        let value = "hi-mom"
        networking.setAuthorizationHeader(headerValue: value)
        let result = try await networking.oldPost("/post")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            let headers = json["headers"] as? [String: Any]
            XCTAssertEqual(value, headers?["Authorization"] as? String)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func setAuthorizationHeaderCustomHeaderKeyAndValue() async throws {
        let networking = Networking(baseURL: baseURL)
        let key = "Anonymous-Token"
        let value = "hi-mom"
        networking.setAuthorizationHeader(headerKey: key, headerValue: value)
        let result = try await networking.oldPost("/post")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            let headers = json["headers"] as? [String: Any]
            XCTAssertEqual(value, headers?[key] as? String)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testURLForPath() throws {
        let networking = Networking(baseURL: baseURL)
        let url = try networking.composedURL(with: "/hello")
        XCTAssertEqual(url.absoluteString, "http://httpbin.org/hello")
    }

    func testURLForPathWithFullPath() throws {
        let networking = Networking()
        let url = try networking.composedURL(with: "http://httpbin.org/hello")
        XCTAssertEqual(url.absoluteString, "http://httpbin.org/hello")
    }

    func testDestinationURL() throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let destinationURL = try networking.destinationURL(for: path)
        XCTAssertEqual(destinationURL.lastPathComponent, "http:--httpbin.org-image-png")
    }

    func testDestinationURLWithFullPath() throws {
        let networking = Networking()
        let path = "http://httpbin.org/image/png"
        let destinationURL = try networking.destinationURL(for: path)
        XCTAssertEqual(destinationURL.lastPathComponent, "http:--httpbin.org-image-png")
    }

    func testDestinationURLWithSpecialCharactersInPath() throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/h�sttur.jpg"
        let destinationURL = try networking.destinationURL(for: path)
        XCTAssertEqual(destinationURL.lastPathComponent, "http:--httpbin.org-h%EF%BF%BDsttur.jpg")
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

    func testStatusCodeType() {
        XCTAssertEqual((URLError.cancelled.rawValue).statusCodeType, Networking.StatusCodeType.cancelled)
        XCTAssertEqual(99.statusCodeType, Networking.StatusCodeType.unknown)
        XCTAssertEqual(100.statusCodeType, Networking.StatusCodeType.informational)
        XCTAssertEqual(199.statusCodeType, Networking.StatusCodeType.informational)
        XCTAssertEqual(200.statusCodeType, Networking.StatusCodeType.successful)
        XCTAssertEqual(299.statusCodeType, Networking.StatusCodeType.successful)
        XCTAssertEqual(300.statusCodeType, Networking.StatusCodeType.redirection)
        XCTAssertEqual(399.statusCodeType, Networking.StatusCodeType.redirection)
        XCTAssertEqual(400.statusCodeType, Networking.StatusCodeType.clientError)
        XCTAssertEqual(499.statusCodeType, Networking.StatusCodeType.clientError)
        XCTAssertEqual(500.statusCodeType, Networking.StatusCodeType.serverError)
        XCTAssertEqual(599.statusCodeType, Networking.StatusCodeType.serverError)
        XCTAssertEqual(600.statusCodeType, Networking.StatusCodeType.unknown)
    }

    func testSplitBaseURLAndRelativePath() {
        let (baseURL1, relativePath1) = Networking.splitBaseURLAndRelativePath(for: "https://rescuejuice.com/wp-content/uploads/2015/11/døgnvillburgere.jpg")
        XCTAssertEqual(baseURL1, "https://rescuejuice.com")
        XCTAssertEqual(relativePath1, "/wp-content/uploads/2015/11/døgnvillburgere.jpg")

        let (baseURL2, relativePath2) = Networking.splitBaseURLAndRelativePath(for: "http://httpbin.org/basic-auth/user/passwd")
        XCTAssertEqual(baseURL2, "http://httpbin.org")
        XCTAssertEqual(relativePath2, "/basic-auth/user/passwd")
    }

    func testReset() throws {
        let networking = Networking(baseURL: baseURL)

        networking.setAuthorizationHeader(username: "user", password: "passwd")
        networking.setAuthorizationHeader(token: "token")
        networking.headerFields = ["HeaderKey": "HeaderValue"]

        XCTAssertEqual(networking.token, "token")
        XCTAssertEqual(networking.authorizationHeaderKey, "Authorization")
        XCTAssertEqual(networking.authorizationHeaderValue, "Basic dXNlcjpwYXNzd2Q=")

        try networking.reset()

        XCTAssertNil(networking.token)
        XCTAssertEqual(networking.authorizationHeaderKey, "Authorization")
        XCTAssertNil(networking.authorizationHeaderValue)
    }
}
