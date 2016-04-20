import Foundation
import XCTest

class NetworkingTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testBasicAuth() {
        let networking = Networking(baseURL: baseURL)
        networking.authenticate(username: "user", password: "passwd")
        networking.GET("/basic-auth/user/passwd", completion: { JSON, error in
            let JSON = JSON as! [String : AnyObject]
            let user = JSON["user"] as! String
            let authenticated = JSON["authenticated"] as! Bool
            XCTAssertEqual(user, "user")
            XCTAssertEqual(authenticated, true)
        })
    }

    func testURLForPath() {
        let networking = Networking(baseURL: baseURL)
        let url = networking.urlForPath("/hello")
        XCTAssertEqual(url.absoluteString, "http://httpbin.org/hello")
    }

    func testSkipTestMode() {
        let expectation = expectationWithDescription("testSkipTestMode")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true

        var synchronous = false
        networking.GET("/get", completion: { JSON, error in
            synchronous = true

            XCTAssertTrue(synchronous)

            expectation.fulfill()
        })

        XCTAssertFalse(synchronous)

        waitForExpectationsWithTimeout(3.0, handler: nil)
    }

    func testDestinationURL() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let destinationURL = networking.destinationURL(path)
        XCTAssertEqual(destinationURL.lastPathComponent!, "http:--httpbin.org-image-png")
    }

    func testStatusCodeType() {
        XCTAssertEqual((-999).statusCodeType(), Networking.StatusCodeType.Unknown)
        XCTAssertEqual(99.statusCodeType(), Networking.StatusCodeType.Unknown)
        XCTAssertEqual(101.statusCodeType(), Networking.StatusCodeType.Informational)
        XCTAssertEqual(203.statusCodeType(), Networking.StatusCodeType.Successful)
        XCTAssertEqual(303.statusCodeType(), Networking.StatusCodeType.Redirection)
        XCTAssertEqual(403.statusCodeType(), Networking.StatusCodeType.ClientError)
        XCTAssertEqual(550.statusCodeType(), Networking.StatusCodeType.ServerError)
    }

    func testSplitBaseURLAndRelativePath() {
        let (baseURL1, relativePath1) = Networking.splitBaseURLAndRelativePath("https://rescuejuice.com/wp-content/uploads/2015/11/døgnvillburgere.jpg")
        XCTAssertEqual(baseURL1, "https://rescuejuice.com")
        XCTAssertEqual(relativePath1, "/wp-content/uploads/2015/11/døgnvillburgere.jpg")

        let (baseURL2, relativePath2) = Networking.splitBaseURLAndRelativePath("http://httpbin.org/basic-auth/user/passwd")
        XCTAssertEqual(baseURL2, "http://httpbin.org")
        XCTAssertEqual(relativePath2, "/basic-auth/user/passwd")
    }
}
