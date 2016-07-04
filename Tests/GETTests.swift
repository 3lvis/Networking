import Foundation
import XCTest

class GETTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testSynchronousGET() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.GET("/get") { JSON, error in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testRequestReturnBlockInMainThread() {
        let expectation = self.expectation(withDescription: "testRequestReturnBlockInMainThread")
        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.GET("/get") { JSON, error in
            XCTAssertTrue(Thread.isMainThread())
            expectation.fulfill()
        }
        self.waitForExpectations(withTimeout: 15.0, handler: nil)
    }

    func testGET() {
        let networking = Networking(baseURL: baseURL)
        networking.GET("/get") { JSON, error in
            guard let JSON = JSON as? [String : AnyObject] else { XCTFail(); return}
            guard let url = JSON["url"] as? String else { XCTFail(); return}
            XCTAssertEqual(url, "http://httpbin.org/get")
        }
    }

    func testGETWithHeaders() {
        let networking = Networking(baseURL: baseURL)
        networking.GET("/get") { JSON, headers, error in
            guard let JSON = JSON as? [String : AnyObject] else { XCTFail(); return}
            guard let url = JSON["url"] as? String else { XCTFail(); return}
            guard let contentType = headers["Content-Type"] as? String else { XCTFail(); return}
            XCTAssertEqual(url, "http://httpbin.org/get")
            XCTAssertEqual(contentType, "application/json")
        }
    }

    func testGETWithInvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.GET("/invalidpath") { JSON, error in
            XCTAssertNil(JSON)
            XCTAssertEqual(error?.code, 404)
        }
    }

    func testFakeGET() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/stories", response: ["name" : "Elvis"])

        networking.GET("/stories") { JSON, error in
            guard let JSON = JSON as? [String : String] else { XCTFail(); return}
            let value = JSON["name"]
            XCTAssertEqual(value, "Elvis")
        }
    }

    func testFakeGETWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/stories", response: nil, statusCode: 401)

        networking.GET("/stories") { JSON, error in
            XCTAssertEqual(error?.code, 401)
        }
    }

    func testFakeGETUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/entries", fileName: "entries.json", bundle: Bundle(for: GETTests.self))

        networking.GET("/entries") { JSON, error in
            guard let JSON = JSON as? [[String : AnyObject]] else { XCTFail(); return }
            let entry = JSON[0]
            let value = entry["title"] as? String
            XCTAssertEqual(value, "Entry 1")
        }
    }

    func testCancelGETWithPath() {
        let expectation = self.expectation(withDescription: "testCancelGET")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        var completed = false
        networking.GET("/get") { JSON, error in
            XCTAssertTrue(completed)
            XCTAssertEqual(error?.code, -999)
            expectation.fulfill()
        }

        networking.cancelGET("/get") {
            completed = true
        }

        self.waitForExpectations(withTimeout: 15.0, handler: nil)
    }

    func testCancelGETWithID() {
        let expectation = self.expectation(withDescription: "testCancelGET")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        var completed = false
        let requestID = networking.GET("/get") { JSON, error in
            XCTAssertTrue(completed)
            XCTAssertEqual(error?.code, -999)
            expectation.fulfill()
        }

        networking.cancel(with: requestID) {
            completed = true
        }

        self.waitForExpectations(withTimeout: 15.0, handler: nil)
    }

    func testStatusCodes() {
        let networking = Networking(baseURL: baseURL)

        networking.GET("/status/200") { JSON, error in
            XCTAssertNil(JSON)
            XCTAssertNil(error)
        }

        var statusCode = 300
        networking.GET("/status/\(statusCode)") { JSON, error in
            XCTAssertNil(JSON)
            let connectionError = NSError(domain: Networking.ErrorDomain, code: statusCode, userInfo: [NSLocalizedDescriptionKey : HTTPURLResponse.localizedString(forStatusCode: statusCode)])
            XCTAssertEqual(error, connectionError)
        }

        statusCode = 400
        networking.GET("/status/\(statusCode)") { JSON, error in
            XCTAssertNil(JSON)
            let connectionError = NSError(domain: Networking.ErrorDomain, code: statusCode, userInfo: [NSLocalizedDescriptionKey : HTTPURLResponse.localizedString(forStatusCode: statusCode)])
            XCTAssertEqual(error, connectionError)
        }
    }
}
