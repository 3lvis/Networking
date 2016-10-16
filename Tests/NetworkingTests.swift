import Foundation
import XCTest

class NetworkingTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testBasicAuth() {
        let networking = Networking(baseURL: baseURL)
        networking.authenticate(username: "user", password: "passwd")
        networking.GET("/basic-auth/user/passwd") { JSON, error in
            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            let user = JSON["user"] as? String
            let authenticated = JSON["authenticated"] as? Bool
            XCTAssertEqual(user, "user")
            XCTAssertEqual(authenticated, true)
        }
    }

    func testBearerTokenAuth() {
        let networking = Networking(baseURL: baseURL)
        let token = "hi-mom"
        networking.authenticate(token: token)
        networking.POST("/post") { JSON, error in
            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            let headers = JSON["headers"] as? [String: Any]
            XCTAssertEqual("Bearer \(token)", headers?["Authorization"] as? String)
        }
    }

    func testCustomAuthorizationHeaderValue() {
        let networking = Networking(baseURL: baseURL)
        let value = "hi-mom"
        networking.authenticate(headerValue: value)
        networking.POST("/post") { JSON, error in
            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            let headers = JSON["headers"] as? [String: Any]
            XCTAssertEqual(value, headers?["Authorization"] as? String)
        }
    }

    func testCustomAuthorizationHeaderValueAndHeaderKey() {
        let networking = Networking(baseURL: baseURL)
        let key = "Anonymous-Token"
        let value = "hi-mom"
        networking.authenticate(headerKey: key, headerValue: value)
        networking.POST("/post") { JSON, error in
            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            let headers = JSON["headers"] as? [String: Any]
            XCTAssertEqual(value, headers?[key] as? String)
        }
    }

    func testSetAuthorizationHeaderWithUsernameAndPassword() {
        let networking = Networking(baseURL: baseURL)
        networking.setAuthorizationHeader(username: "user", password: "passwd")
        networking.GET("/basic-auth/user/passwd") { JSON, error in
            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            let user = JSON["user"] as? String
            let authenticated = JSON["authenticated"] as? Bool
            XCTAssertEqual(user, "user")
            XCTAssertEqual(authenticated, true)
        }
    }

    func testSetAuthorizationHeaderWithBearerToken() {
        let networking = Networking(baseURL: baseURL)
        let token = "hi-mom"
        networking.setAuthorizationHeader(token: token)
        networking.POST("/post") { JSON, error in
            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            let headers = JSON["headers"] as? [String: Any]
            XCTAssertEqual("Bearer \(token)", headers?["Authorization"] as? String)
        }
    }

    func setAuthorizationHeaderCustomValue() {
        let networking = Networking(baseURL: baseURL)
        let value = "hi-mom"
        networking.setAuthorizationHeader(headerValue: value)
        networking.POST("/post") { JSON, error in
            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            let headers = JSON["headers"] as? [String: Any]
            XCTAssertEqual(value, headers?["Authorization"] as? String)
        }
    }

    func setAuthorizationHeaderCustomHeaderKeyAndValue() {
        let networking = Networking(baseURL: baseURL)
        let key = "Anonymous-Token"
        let value = "hi-mom"
        networking.setAuthorizationHeader(headerKey: key, headerValue: value)
        networking.POST("/post") { JSON, error in
            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            let headers = JSON["headers"] as? [String: Any]
            XCTAssertEqual(value, headers?[key] as? String)
        }
    }

    func testHeaderField() {
        let networking = Networking(baseURL: baseURL)
        networking.headerFields = ["HeaderKey": "HeaderValue"]
        networking.POST("/post") { JSON, error in
            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            let headers = JSON["headers"] as? [String: Any]
            XCTAssertEqual("HeaderValue", headers?["Headerkey"] as? String)
        }
    }

    func testURLForPath() {
        let networking = Networking(baseURL: baseURL)
        let url = networking.url(for: "/hello")
        XCTAssertEqual(url.absoluteString, "http://httpbin.org/hello")
    }

    func testSkipTestMode() {
        let expectation = self.expectation(description: "testSkipTestMode")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true

        var synchronous = false
        networking.GET("/get") { JSON, error in
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
        XCTAssertEqual((-999).statusCodeType(), Networking.StatusCodeType.unknown)
        XCTAssertEqual(99.statusCodeType(), Networking.StatusCodeType.unknown)
        XCTAssertEqual(101.statusCodeType(), Networking.StatusCodeType.informational)
        XCTAssertEqual(203.statusCodeType(), Networking.StatusCodeType.successful)
        XCTAssertEqual(303.statusCodeType(), Networking.StatusCodeType.redirection)
        XCTAssertEqual(403.statusCodeType(), Networking.StatusCodeType.clientError)
        XCTAssertEqual(550.statusCodeType(), Networking.StatusCodeType.serverError)
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

        let requestID = networking.GET("/get") { JSON, error in
            cancelledGET = error?.code == -999
            XCTAssertTrue(cancelledGET)

            if cancelledGET {
                expectation.fulfill()
            }
        }

        networking.cancel(with: requestID, completion: nil)

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelAllRequests() {
        let expectation = self.expectation(description: "testCancelAllRequests")
        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        var cancelledGET = false
        var cancelledPOST = false

        networking.GET("/get") { JSON, error in
            cancelledGET = error?.code == -999
            XCTAssertTrue(cancelledGET)

            if cancelledGET && cancelledPOST {
                expectation.fulfill()
            }
        }

        networking.POST("/post") { JSON, error in
            cancelledPOST = error?.code == -999
            XCTAssertTrue(cancelledPOST)

            if cancelledGET && cancelledPOST {
                expectation.fulfill()
            }
        }

        networking.cancelAllRequests(with: nil)

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelRequestsReturnInMainThread() {
        let expectation = self.expectation(description: "testCancelRequestsReturnInMainThread")
        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.GET("/get") { JSON, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(error?.code, -999)
            expectation.fulfill()
        }
        networking.cancelAllRequests(with: nil)
        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testDownloadData() {
        var synchronous = false
        let networking = Networking(baseURL: self.baseURL)
        let path = "/image/png"
        Helper.removeFileIfNeeded(networking, path: path)
        networking.downloadData(for: path) { data, error in
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

        networking.downloadData(for: path) { downloadData, error in
            let cacheKey = path.components(separatedBy: "?").first!
            let cacheData = networking.dataFromCache(for: cacheKey)
            XCTAssert(downloadData == cacheData!)
        }
    }

    func testDeleteDownloadedFiles() {
        let networking = Networking(baseURL: self.baseURL)
        networking.downloadImage("/image/png") { image, error in
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
}
