import Foundation
import XCTest

class NetworkingTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testSetAuthorizationHeaderWithUsernameAndPassword() {
        let networking = Networking(baseURL: baseURL)
        networking.setAuthorizationHeader(username: "user", password: "passwd")
        networking.GET("/basic-auth/user/passwd") { json, _ in
            guard let json = json as? [String: Any] else { XCTFail(); return }
            let user = json["user"] as? String
            let authenticated = json["authenticated"] as? Bool
            XCTAssertEqual(user, "user")
            XCTAssertEqual(authenticated, true)
        }
    }

    func testSetAuthorizationHeaderWithBearerToken() {
        let networking = Networking(baseURL: baseURL)
        let token = "hi-mom"
        networking.setAuthorizationHeader(token: token)
        networking.POST("/post") { json, _ in
            guard let json = json as? [String: Any] else { XCTFail(); return }
            let headers = json["headers"] as? [String: Any]
            XCTAssertEqual("Bearer \(token)", headers?["Authorization"] as? String)
        }
    }

    func setAuthorizationHeaderCustomValue() {
        let networking = Networking(baseURL: baseURL)
        let value = "hi-mom"
        networking.setAuthorizationHeader(headerValue: value)
        networking.POST("/post") { json, _ in
            guard let json = json as? [String: Any] else { XCTFail(); return }
            let headers = json["headers"] as? [String: Any]
            XCTAssertEqual(value, headers?["Authorization"] as? String)
        }
    }

    func setAuthorizationHeaderCustomHeaderKeyAndValue() {
        let networking = Networking(baseURL: baseURL)
        let key = "Anonymous-Token"
        let value = "hi-mom"
        networking.setAuthorizationHeader(headerKey: key, headerValue: value)
        networking.POST("/post") { json, _ in
            guard let json = json as? [String: Any] else { XCTFail(); return }
            let headers = json["headers"] as? [String: Any]
            XCTAssertEqual(value, headers?[key] as? String)
        }
    }

    func testHeaderField() {
        let networking = Networking(baseURL: baseURL)
        networking.headerFields = ["HeaderKey": "HeaderValue"]
        networking.POST("/post") { json, _ in
            guard let json = json as? [String: Any] else { XCTFail(); return }
            let headers = json["headers"] as? [String: Any]
            XCTAssertEqual("HeaderValue", headers?["Headerkey"] as? String)
        }
    }

    func testURLForPath() {
        let networking = Networking(baseURL: baseURL)
        let url = try! networking.url(for: "/hello")
        XCTAssertEqual(url.absoluteString, "http://httpbin.org/hello")
    }

    func testSkipTestMode() {
        let expectation = self.expectation(description: "testSkipTestMode")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true

        var synchronous = false
        networking.GET("/get") { _, _ in
            synchronous = true

            XCTAssertTrue(synchronous)

            expectation.fulfill()
        }

        XCTAssertFalse(synchronous)

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testDestinationURL() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
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
        XCTAssertEqual((URLError.cancelled.rawValue).statusCodeType(), Networking.StatusCodeType.cancelled)
        XCTAssertEqual(99.statusCodeType(), Networking.StatusCodeType.unknown)
        XCTAssertEqual(100.statusCodeType(), Networking.StatusCodeType.informational)
        XCTAssertEqual(199.statusCodeType(), Networking.StatusCodeType.informational)
        XCTAssertEqual(200.statusCodeType(), Networking.StatusCodeType.successful)
        XCTAssertEqual(299.statusCodeType(), Networking.StatusCodeType.successful)
        XCTAssertEqual(300.statusCodeType(), Networking.StatusCodeType.redirection)
        XCTAssertEqual(399.statusCodeType(), Networking.StatusCodeType.redirection)
        XCTAssertEqual(400.statusCodeType(), Networking.StatusCodeType.clientError)
        XCTAssertEqual(499.statusCodeType(), Networking.StatusCodeType.clientError)
        XCTAssertEqual(500.statusCodeType(), Networking.StatusCodeType.serverError)
        XCTAssertEqual(599.statusCodeType(), Networking.StatusCodeType.serverError)
        XCTAssertEqual(600.statusCodeType(), Networking.StatusCodeType.unknown)
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
        networking.disableTestingMode = true
        var cancelledGET = false

        let requestID = networking.GET("/get") { _, error in
            cancelledGET = error?.code == URLError.cancelled.rawValue
            XCTAssertTrue(cancelledGET)

            if cancelledGET {
                expectation.fulfill()
            }
        }

        networking.cancel(with: requestID)

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelAllRequests() {
        let expectation = self.expectation(description: "testCancelAllRequests")
        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        var cancelledGET = false
        var cancelledPOST = false

        networking.GET("/get") { _, error in
            cancelledGET = error?.code == URLError.cancelled.rawValue
            XCTAssertTrue(cancelledGET)

            if cancelledGET && cancelledPOST {
                expectation.fulfill()
            }
        }

        networking.POST("/post") { _, error in
            cancelledPOST = error?.code == URLError.cancelled.rawValue
            XCTAssertTrue(cancelledPOST)

            if cancelledGET && cancelledPOST {
                expectation.fulfill()
            }
        }

        networking.cancelAllRequests()

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelRequestsReturnInMainThread() {
        let expectation = self.expectation(description: "testCancelRequestsReturnInMainThread")
        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.GET("/get") { _, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(error?.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }
        networking.cancelAllRequests()
        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testDownloadData() {
        var synchronous = false
        let networking = Networking(baseURL: self.baseURL)
        let path = "/image/png"
        try! Helper.removeFileIfNeeded(networking, path: path)
        networking.downloadData(for: path) { data, _ in
            synchronous = true
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(data?.count, 8090)
        }
        XCTAssertTrue(synchronous)
    }

    func testDataFromCache() {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: "http://store.storeimages.cdn-apple.com", cache: cache)
        let path = "/4973/as-images.apple.com/is/image/AppleInc/aos/published/images/i/pa/ipad/pro/ipad-pro-201603-gallery3?wid=4000&amp%3Bhei=1536&amp%3Bfmt=jpeg&amp%3Bqlt=95&amp%3Bop_sharpen=0&amp%3BresMode=bicub&amp%3Bop_usm=0.5%2C0.5%2C0%2C0&amp%3BiccEmbed=0&amp%3Blayer=comp&amp%3B.v=Y7wkx0&hei=3072"

        networking.downloadData(for: path) { downloadData, _ in
            let cacheData = networking.dataFromCache(for: path)
            XCTAssert(downloadData == cacheData!)
        }
    }

    func testDeleteDownloadedFiles() {
        let networking = Networking(baseURL: self.baseURL)
        networking.downloadImage("/image/png") { _, _ in
            #if os(tvOS)
                let directory = FileManager.SearchPathDirectory.cachesDirectory
            #else
                let directory = TestCheck.isTesting ? FileManager.SearchPathDirectory.cachesDirectory : FileManager.SearchPathDirectory.documentDirectory
            #endif
            let cachesURL = FileManager.default.urls(for: directory, in: .userDomainMask).first!
            let folderURL = cachesURL.appendingPathComponent(URL(string: Networking.domain)!.absoluteString)
            XCTAssertTrue(FileManager.default.exists(at: folderURL))
            Networking.deleteCachedFiles()
            XCTAssertFalse(FileManager.default.exists(at: folderURL))
        }
    }

    func testReset() {
        let networking = Networking(baseURL: self.baseURL)

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
}
