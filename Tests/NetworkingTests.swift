import Foundation
import XCTest

class NetworkingTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testSetAuthorizationHeaderWithUsernameAndPassword() {
        let networking = Networking(baseURL: baseURL)
        networking.setAuthorizationHeader(username: "user", password: "passwd")
        networking.get("/basic-auth/user/passwd") { result in
            switch result {
            case let .success(response):
                let json = response.dictionaryBody
                let user = json["user"] as? String
                let authenticated = json["authenticated"] as? Bool
                XCTAssertEqual(user, "user")
                XCTAssertEqual(authenticated, true)
            case .failure:
                XCTFail()
            }
        }
    }

    func testSetAuthorizationHeaderWithBearerToken() {
        let networking = Networking(baseURL: baseURL)
        let token = "hi-mom"
        networking.setAuthorizationHeader(token: token)
        networking.post("/post") { result in
            switch result {
            case let .success(response):
                let json = response.dictionaryBody
                let headers = json["headers"] as? [String: Any]
                XCTAssertEqual("Bearer \(token)", headers?["Authorization"] as? String)
            case .failure:
                XCTFail()
            }
        }
    }

    func setAuthorizationHeaderCustomValue() {
        let networking = Networking(baseURL: baseURL)
        let value = "hi-mom"
        networking.setAuthorizationHeader(headerValue: value)
        networking.post("/post") { result in
            switch result {
            case let .success(response):
                let json = response.dictionaryBody
                let headers = json["headers"] as? [String: Any]
                XCTAssertEqual(value, headers?["Authorization"] as? String)
            case .failure:
                XCTFail()
            }
        }
    }

    func setAuthorizationHeaderCustomHeaderKeyAndValue() {
        let networking = Networking(baseURL: baseURL)
        let key = "Anonymous-Token"
        let value = "hi-mom"
        networking.setAuthorizationHeader(headerKey: key, headerValue: value)
        networking.post("/post") { result in
            switch result {
            case let .success(response):
                let json = response.dictionaryBody
                let headers = json["headers"] as? [String: Any]
                XCTAssertEqual(value, headers?[key] as? String)
            case .failure:
                XCTFail()
            }
        }
    }

    func testHeaderField() {
        let networking = Networking(baseURL: baseURL)
        networking.headerFields = ["HeaderKey": "HeaderValue"]
        networking.post("/post") { result in
            switch result {
            case let .success(response):
                let json = response.dictionaryBody
                let headers = json["headers"] as? [String: Any]
                XCTAssertEqual("HeaderValue", headers?["Headerkey"] as? String)
            case .failure:
                XCTFail()
            }
        }
    }

    func testURLForPath() {
        let networking = Networking(baseURL: baseURL)
        let url = try! networking.composedURL(with: "/hello")
        XCTAssertEqual(url.absoluteString, "http://httpbin.org/hello")
    }

    func testURLForPathWithFullPath() {
        let networking = Networking()
        let url = try! networking.composedURL(with: "http://httpbin.org/hello")
        XCTAssertEqual(url.absoluteString, "http://httpbin.org/hello")
    }

    func testSkipTestMode() {
        let expectation = self.expectation(description: "testSkipTestMode")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true

        var synchronous = false
        networking.get("/get") { _ in
            synchronous = true

            XCTAssertTrue(synchronous)

            expectation.fulfill()
        }

        XCTAssertFalse(synchronous)

        waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testDestinationURL() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        guard let destinationURL = try? networking.destinationURL(for: path) else { XCTFail(); return }
        XCTAssertEqual(destinationURL.lastPathComponent, "http:--httpbin.org-image-png")
    }

    func testDestinationURLWithFullPath() {
        let networking = Networking()
        let path = "http://httpbin.org/image/png"
        guard let destinationURL = try? networking.destinationURL(for: path) else { XCTFail(); return }
        XCTAssertEqual(destinationURL.lastPathComponent, "http:--httpbin.org-image-png")
    }

    func testDestinationURLWithSpecialCharactersInPath() {
        let networking = Networking(baseURL: baseURL)
        let path = "/h�sttur.jpg"
        guard let destinationURL = try? networking.destinationURL(for: path) else { XCTFail(); return }
        XCTAssertEqual(destinationURL.lastPathComponent, "http:--httpbin.org-h%EF%BF%BDsttur.jpg")
    }

    func testDestinationURLWithSpecialCharactersInCacheName() {
        let networking = Networking(baseURL: baseURL)
        let path = "/the-url-doesnt-really-matter"
        guard let destinationURL = try? networking.destinationURL(for: path, cacheName: "h�sttur.jpg-25-03/small") else { XCTFail(); return }
        XCTAssertEqual(destinationURL.lastPathComponent, "h%EF%BF%BDsttur.jpg-25-03-small")
    }

    func testDestinationURLCache() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "png/png"
        guard let destinationURL = try? networking.destinationURL(for: path, cacheName: cacheName) else { XCTFail(); return }
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

    func testCancelWithRequestID() {
        let expectation = self.expectation(description: "testCancelAllRequests")
        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        var cancelledGET = false

        let requestID = networking.get("/get") { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                cancelledGET = response.error.code == URLError.cancelled.rawValue
                XCTAssertTrue(cancelledGET)

                if cancelledGET {
                    expectation.fulfill()
                }
            }
        }

        networking.cancel(requestID)

        waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelAllRequests() {
        let expectation = self.expectation(description: "testCancelAllRequests")
        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        var cancelledGET = false
        var cancelledPOST = false

        networking.get("/get") { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                cancelledGET = response.error.code == URLError.cancelled.rawValue
                XCTAssertTrue(cancelledGET)

                if cancelledGET && cancelledPOST {
                    expectation.fulfill()
                }
            }
        }

        networking.post("/post") { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                cancelledPOST = response.error.code == URLError.cancelled.rawValue
                XCTAssertTrue(cancelledPOST)

                if cancelledGET && cancelledPOST {
                    expectation.fulfill()
                }
            }
        }

        networking.cancelAllRequests()

        waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelRequestsReturnInMainThread() {
        let expectation = self.expectation(description: "testCancelRequestsReturnInMainThread")
        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        networking.get("/get") { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(response.error.code, URLError.cancelled.rawValue)
                expectation.fulfill()
            }
        }
        networking.cancelAllRequests()
        waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testReset() {
        let networking = Networking(baseURL: baseURL)

        networking.setAuthorizationHeader(username: "user", password: "passwd")
        networking.setAuthorizationHeader(token: "token")
        networking.headerFields = ["HeaderKey": "HeaderValue"]

        XCTAssertEqual(networking.token, "token")
        XCTAssertEqual(networking.authorizationHeaderKey, "Authorization")
        XCTAssertEqual(networking.authorizationHeaderValue, "Basic dXNlcjpwYXNzd2Q=")

        networking.reset()

        XCTAssertNil(networking.token)
        XCTAssertEqual(networking.authorizationHeaderKey, "Authorization")
        XCTAssertNil(networking.authorizationHeaderValue)
    }

    func testDeleteCachedFiles() {
        let directory = FileManager.SearchPathDirectory.cachesDirectory
        let cachesURL = FileManager.default.urls(for: directory, in: .userDomainMask).first!
        let folderURL = cachesURL.appendingPathComponent(URL(string: Networking.domain)!.absoluteString)

        let networking = Networking(baseURL: baseURL)
        networking.downloadImage("/image/png") { _ in
            let image = Image.find(named: "sample.jpg", inBundle: Bundle(for: NetworkingTests.self))
            let data = image.jpgData()
            let filename = cachesURL.appendingPathComponent("sample.jpg")
            ((try? data?.write(to: filename)) as ()??)

            XCTAssertTrue(FileManager.default.exists(at: cachesURL))
            XCTAssertTrue(FileManager.default.exists(at: folderURL))
            XCTAssertTrue(FileManager.default.exists(at: filename))

            Networking.deleteCachedFiles()

            // Caches folder should be there
            XCTAssertTrue(FileManager.default.exists(at: cachesURL))

            // Files under networking domain are gone
            XCTAssertFalse(FileManager.default.exists(at: folderURL))

            // Saved image should be there
            XCTAssertTrue(FileManager.default.exists(at: filename))
        }
    }
}
