import Foundation
import XCTest

class GETTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testSynchronousGET() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.GET("/get") { json, error in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testRequestReturnBlockInMainThread() {
        let expectation = self.expectation(description: "testRequestReturnBlockInMainThread")
        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        networking.GET("/get") { json, error in
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testGET() {
        let networking = Networking(baseURL: baseURL)
        networking.GET("/get") { json, error in
            print(String(data: try! JSONSerialization.data(withJSONObject: json!, options: .prettyPrinted), encoding: .utf8)!)
            guard let json = json as? [String: Any] else { XCTFail(); return }

            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "http://httpbin.org/get")

            guard let headers = json["headers"] as? [String: String] else { XCTFail(); return }
            let contentType = headers["Content-Type"]
            XCTAssertNil(contentType)
        }
    }

    func testGETWithHeaders() {
        let networking = Networking(baseURL: baseURL)
        networking.GET("/get") { json, headers, error in
            guard let json = json as? [String: Any] else { XCTFail(); return }
            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "http://httpbin.org/get")

            guard let connection = headers["Connection"] as? String else { XCTFail(); return }
            XCTAssertEqual(connection, "keep-alive")
            XCTAssertEqual(headers["Content-Type"] as? String, "application/json")
        }
    }

    func testGETWithInvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.GET("/invalidpath") { json, error in
            XCTAssertNil(json)
            XCTAssertEqual(error?.code, 404)
        }
    }

    // TODO: I'm not sure how it implement this, since I need a service that returns a faulty
    // status code, meaning not 2XX, and at the same time it returns a JSON response.
    func testGETWithInvalidPathAndJSONError() {
    }

    func testFakeGET() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/stories", response: ["name": "Elvis"])

        networking.GET("/stories") { json, error in
            guard let json = json as? [String: String] else { XCTFail(); return }
            let value = json["name"]
            XCTAssertEqual(value, "Elvis")
        }
    }

    func testFakeGETWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/stories", response: nil, statusCode: 401)

        networking.GET("/stories") { json, error in
            XCTAssertEqual(error?.code, 401)
        }
    }

    func testFakeGETWithInvalidPathAndJSONError() {
        let networking = Networking(baseURL: baseURL)

        let response = ["error_message": "Shit went down"]
        networking.fakeGET("/stories", response: response, statusCode: 401)

        networking.GET("/stories") { json, error in
            XCTAssertEqual(json as! [String: String], response)
            XCTAssertEqual(error?.code, 401)
        }
    }

    func testFakeGETUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/entries", fileName: "entries.json", bundle: Bundle(for: GETTests.self))

        networking.GET("/entries") { json, error in
            guard let json = json as? [[String: Any]] else { XCTFail(); return }
            let entry = json[0]
            let value = entry["title"] as? String
            XCTAssertEqual(value, "Entry 1")
        }
    }

    func testCancelGETWithPath() {
        let expectation = self.expectation(description: "testCancelGET")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        var completed = false
        networking.GET("/get") { json, error in
            XCTAssertTrue(completed)
            XCTAssertEqual(error?.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }

        networking.cancelGET("/get")
        completed = true


        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelGETWithID() {
        let expectation = self.expectation(description: "testCancelGET")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        var completed = false
        let requestID = networking.GET("/get") { json, error in
            XCTAssertTrue(completed)
            XCTAssertEqual(error?.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }

        networking.cancel(with: requestID) {
            completed = true
        }

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testStatusCodes() {
        let networking = Networking(baseURL: baseURL)

        networking.GET("/status/200") { json, error in
            XCTAssertNil(json)
            XCTAssertNil(error)
        }

        var statusCode = 300
        networking.GET("/status/\(statusCode)") { json, error in
            XCTAssertNil(json)
            let connectionError = NSError(domain: Networking.domain, code: statusCode, userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: statusCode)])
            XCTAssertEqual(error, connectionError)
        }

        statusCode = 400
        networking.GET("/status/\(statusCode)") { json, error in
            XCTAssertNil(json)
            let connectionError = NSError(domain: Networking.domain, code: statusCode, userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: statusCode)])
            XCTAssertEqual(error, connectionError)
        }
    }

    func testGETWithURLEncodedParameters() {
        let networking = Networking(baseURL: baseURL)
        networking.GET("/get", parameters: ["count": 25]) { json, error in
            let json = json as? [String: Any] ?? [String: Any]()
            XCTAssertEqual(json["url"] as? String, "http://httpbin.org/get?count=25")
        }
    }

    func testGETWithURLEncodedParametersWithExistingQuery() {
        let networking = Networking(baseURL: baseURL)
        networking.GET("/get?accountId=123", parameters: ["userId": 5]) { json, error in
            let json = json as? [String: Any] ?? [String: Any]()
            XCTAssertEqual(json["url"] as? String, "http://httpbin.org/get?accountId=123&userId=5")
        }
    }

    func testGETWithURLEncodedParametersWithPercentEncoding() {
        let networking = Networking(baseURL: baseURL)
        networking.GET("/get", parameters: ["name": "Elvis Nuñez"]) { json, error in
            let json = json as? [String: Any] ?? [String: Any]()
            XCTAssertEqual(json["url"] as? String, "http://httpbin.org/get?name=Elvis Nuñez")
        }
    }
}
