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
            case let .success(response):
                let json = response.dictionaryBody

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

    func testGETWithFullPath() {
        let networking = Networking()
        networking.get("http://httpbin.org/get") { result in
            switch result {
            case let .success(response):
                let json = response.dictionaryBody

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
            case let .success(response):
                let json = response.dictionaryBody
                guard let url = json["url"] as? String else { XCTFail(); return }
                XCTAssertEqual(url, "http://httpbin.org/get")

                let headers = response.headers
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
            case let .failure(response):
                XCTAssertEqual(response.error.code, 404)
            }
        }
    }

    // I'm not sure how it implement this, since I need a service that returns a faulty status code, meaning not 2XX, and at the same time it returns a JSON response.
    func testGETWithInvalidPathAndJSONError() {
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
            case let .failure(response):
                XCTAssertTrue(completed)
                XCTAssertEqual(response.error.code, URLError.cancelled.rawValue)
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
            case let .failure(response):
                XCTAssertEqual(response.error.code, URLError.cancelled.rawValue)
                expectation.fulfill()
            }
        }

        networking.cancel(requestID)

        waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testStatusCodes() {
        let networking = Networking(baseURL: baseURL)

        networking.get("/status/200") { result in
            switch result {
            case let .success(response):
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
            case let .failure(response):
                let connectionError = NSError(domain: Networking.domain, code: statusCode, userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: statusCode)])
                XCTAssertEqual(response.error, connectionError)
            }
        }

        statusCode = 400
        networking.get("/status/\(statusCode)") { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                let connectionError = NSError(domain: Networking.domain, code: statusCode, userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: statusCode)])
                XCTAssertEqual(response.error, connectionError)
            }
        }
    }

    func testGETWithURLEncodedParameters() {
        let networking = Networking(baseURL: baseURL)
        networking.get("/get", parameters: ["count": 25]) { result in
            switch result {
            case let .success(response):
                let json = response.dictionaryBody
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
            case let .success(response):
                let json = response.dictionaryBody
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
            case let .success(response):
                let json = response.dictionaryBody
                XCTAssertEqual(json["url"] as? String, "http://httpbin.org/get?name=Elvis Nuñez")
            case .failure:
                XCTFail()
            }
        }
    }

    func testGETCachedFromMemory() {
        let networking = Networking(baseURL: baseURL)
        networking.fakeGET("/get", response: ["key": "value1"])
        networking.get("/get", cachingLevel: .memory) { _ in }
        networking.fakeGET("/get", response: ["key": "value2"])
        var callbackCount = 0
        networking.get("/get", cachingLevel: .memory) { result in
            if callbackCount == 0 {
                switch result {
                case let .success(response):
                    let json = response.dictionaryBody
                    XCTAssertEqual(json["key"] as? String, "value1")
                case .failure:
                    XCTFail()
                }
            } else {
                switch result {
                case let .success(response):
                    let json = response.dictionaryBody
                    XCTAssertEqual(json["key"] as? String, "value2")
                case .failure:
                    XCTFail()
                }
            }
            callbackCount += 1
        }
    }

    func testGETCachedFromFile() {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, configuration: .default, cache: cache)
        networking.fakeGET("/get", response: ["key": "value1"])
        networking.get("/get", cachingLevel: .memoryAndFile) { _ in }
        networking.fakeGET("/get", response: ["key": "value2"])
        var callbackCount = 0
        cache.removeAllObjects()
        networking.get("/get", cachingLevel: .memoryAndFile) { result in
            if callbackCount == 0 {
                switch result {
                case let .success(response):
                    let json = response.dictionaryBody
                    XCTAssertEqual(json["key"] as? String, "value1")
                case .failure(let response):
                    XCTFail("Error: \(response.error)")
                }
            } else {
                switch result {
                case let .success(response):
                    let json = response.dictionaryBody
                    XCTAssertEqual(json["key"] as? String, "value2")
                case .failure:
                    XCTFail()
                }
            }
            callbackCount += 1
        }
    }
}
