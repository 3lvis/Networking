import Foundation
import XCTest

class GETTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testSynchronousGET() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.get("/get") { _ in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testRequestReturnBlockInMainThread() {
        let expectation = self.expectation(description: "testRequestReturnBlockInMainThread")
        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        networking.get("/get") { _ in
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testGET() {
        let networking = Networking(baseURL: baseURL)
        networking.get("/get") { result in
            switch result {
            case .success(let json, _):
                let json = json.dictionary

                guard let url = json["url"] as? String else { XCTFail(); return }
                XCTAssertEqual(url, "http://httpbin.org/get")

                guard let headers = json["headers"] as? [String: String] else { XCTFail(); return }
                let contentType = headers["Content-Type"]
                XCTAssertNil(contentType)
            case .failure:
                XCTFail()
            }
        }
    }

    func testGETWithHeaders() {
        let networking = Networking(baseURL: baseURL)
        networking.get("/get") { result in
            switch result {
            case .success(let json, let response):
                let json = json.dictionary
                guard let url = json["url"] as? String else { XCTFail(); return }
                XCTAssertEqual(url, "http://httpbin.org/get")

                let headers = response.allHeaderFields
                guard let connection = headers["Connection"] as? String else { XCTFail(); return }
                XCTAssertEqual(connection, "keep-alive")
                XCTAssertEqual(headers["Content-Type"] as? String, "application/json")
            case .failure:
                XCTFail()
            }
        }
    }

    func testGETWithInvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.get("/invalidpath") { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(_, _, let error):
                XCTAssertEqual(error.code, 404)
            }
        }
    }

    // I'm not sure how it implement this, since I need a service that returns a faulty status code, meaning not 2XX, and at the same time it returns a JSON response.
    func testGETWithInvalidPathAndJSONError() {
    }

    func testFakeGET() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/stories", response: ["name": "Elvis"])

        networking.get("/stories") { result in
            switch result {
            case .success(let json, _):
                let json = json.dictionary
                let value = json["name"] as? String
                XCTAssertEqual(value, "Elvis")
            case .failure:
                XCTFail()
            }
        }
    }

    func testFakeGETWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/stories", response: nil, statusCode: 401)

        networking.get("/stories") { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(_, _, let error):
                XCTAssertEqual(error.code, 401)
            }
        }
    }

    func testFakeGETWithInvalidPathAndJSONError() {
        let networking = Networking(baseURL: baseURL)

        let response = ["error_message": "Shit went down"]
        networking.fakeGET("/stories", response: response, statusCode: 401)

        networking.get("/stories") { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(let json, _, let error):
                let json = json.dictionary
                XCTAssertEqual(json as! [String: String], response)
                XCTAssertEqual(error.code, 401)
            }
        }
    }

    func testFakeGETUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/entries", fileName: "entries.json", bundle: Bundle(for: GETTests.self))

        networking.get("/entries") { result in
            switch result {
            case .success(let json, _):
                let json = json.array
                let entry = json[0]
                let value = entry["title"] as? String
                XCTAssertEqual(value, "Entry 1")
            case .failure:
                XCTFail()
            }
        }
    }

    func testCancelGETWithPath() {
        let expectation = self.expectation(description: "testCancelGET")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        var completed = false
        networking.get("/get") { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(_, _, let error):
                XCTAssertTrue(completed)
                XCTAssertEqual(error.code, URLError.cancelled.rawValue)
                expectation.fulfill()
            }
        }

        networking.cancelGET("/get")
        completed = true

        waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelGETWithID() {
        let expectation = self.expectation(description: "testCancelGET")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        let requestID = networking.get("/get") { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(_, _, let error):
                XCTAssertEqual(error.code, URLError.cancelled.rawValue)
                expectation.fulfill()
            }
        }

        networking.cancel(with: requestID)

        waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testStatusCodes() {
        let networking = Networking(baseURL: baseURL)

        networking.get("/status/200") { result in
            switch result {
            case .success(_, let response):
                XCTAssertEqual(response.statusCode, 200)
            case .failure:
                XCTFail()
            }
        }

        var statusCode = 300
        networking.get("/status/\(statusCode)") { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(_, _, let error):
                let connectionError = NSError(domain: Networking.domain, code: statusCode, userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: statusCode)])
                XCTAssertEqual(error, connectionError)
            }
        }

        statusCode = 400
        networking.get("/status/\(statusCode)") { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(_, _, let error):
                let connectionError = NSError(domain: Networking.domain, code: statusCode, userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: statusCode)])
                XCTAssertEqual(error, connectionError)
            }
        }
    }

    func testGETWithURLEncodedParameters() {
        let networking = Networking(baseURL: baseURL)
        networking.get("/get", parameters: ["count": 25]) { result in
            switch result {
            case .success(let json, _):
                let json = json.dictionary
                XCTAssertEqual(json["url"] as? String, "http://httpbin.org/get?count=25")
            case .failure:
                XCTFail()
            }
        }
    }

    func testGETWithURLEncodedParametersWithExistingQuery() {
        let networking = Networking(baseURL: baseURL)
        networking.get("/get?accountId=123", parameters: ["userId": 5]) { result in
            switch result {
            case .success(let json, _):
                let json = json.dictionary
                XCTAssertEqual(json["url"] as? String, "http://httpbin.org/get?accountId=123&userId=5")
            case .failure:
                XCTFail()
            }
        }
    }

    func testGETWithURLEncodedParametersWithPercentEncoding() {
        let networking = Networking(baseURL: baseURL)
        networking.get("/get", parameters: ["name": "Elvis Nuñez"]) { result in
            switch result {
            case .success(let json, _):
                let json = json.dictionary
                XCTAssertEqual(json["url"] as? String, "http://httpbin.org/get?name=Elvis Nuñez")
            case .failure:
                XCTFail()
            }
        }
    }
}
