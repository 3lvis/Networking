import Foundation
import XCTest
@testable import Networking

class GETTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testSynchronousGET() async throws {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        let _ = try await networking.get("/get")
        synchronous = true
        XCTAssertTrue(synchronous)
    }

    func testGET() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.get("/get")
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

    func testGETWithFullPath() async throws {
        let networking = Networking()
        let result = try await networking.get("http://httpbin.org/get")
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

    func testGETWithHeaders() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.get("/get")
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

    func testGETWithInvalidPath() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.get("/invalidpath")
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertEqual(response.error.code, 404)
        }
    }

    // I'm not sure how it implement this, since I need a service that returns a faulty status code, meaning not 2XX, and at the same time it returns a JSON response.
    func testGETWithInvalidPathAndJSONError() {
    }

    func testCancelGETWithPath() async throws {
        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        var completed = false
        let result = try await networking.get("/get")
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertTrue(completed)
            XCTAssertEqual(response.error.code, URLError.cancelled.rawValue)
        }

        networking.cancelGET("/get")
        completed = true
    }

    func testCancelGETWithID() async throws {
        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        let result = try await networking.get("/get")
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertEqual(response.error.code, URLError.cancelled.rawValue)
        }

        // networking.cancel(requestID)
    }

    func testStatusCodes() async throws {
        let networking = Networking(baseURL: baseURL)
        let result200 = try await networking.get("/status/200")
        switch result200 {
        case let .success(response):
            XCTAssertEqual(response.statusCode, 200)
        case .failure:
            XCTFail()
        }

        var statusCode = 300
        let result300 = try await networking.get("/status/\(statusCode)")
        switch result300 {
        case .success:
            XCTFail()
        case let .failure(response):
            let connectionError = NSError(domain: Networking.domain, code: statusCode, userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: statusCode)])
            XCTAssertEqual(response.error, connectionError)
        }

        statusCode = 400
        let result400 = try await networking.get("/status/\(statusCode)")
        switch result400 {
        case .success:
            XCTFail()
        case let .failure(response):
            let connectionError = NSError(domain: Networking.domain, code: statusCode, userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: statusCode)])
            XCTAssertEqual(response.error, connectionError)
        }
    }

    func testGETWithURLEncodedParameters() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.get("/get", parameters: ["count": 25])
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["url"] as? String, "http://httpbin.org/get?count=25")
        case .failure:
            XCTFail()
        }
    }

    func testGETWithURLEncodedParametersWithExistingQuery() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.get("/get?accountId=123", parameters: ["userId": 5])
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["url"] as? String, "http://httpbin.org/get?accountId=123&userId=5")
        case .failure:
            XCTFail()
        }
    }

    func testGETWithURLEncodedParametersWithPercentEncoding() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.get("/get", parameters: ["name": "Elvis Nuñez"])
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["url"] as? String, "http://httpbin.org/get?name=Elvis Nuñez")
        case .failure:
            XCTFail()
        }
    }

    func testGETCachedFromMemory() async throws {
        let networking = Networking(baseURL: baseURL)
        networking.fakeGET("/get", response: ["key": "value1"])
        let _ = try await networking.get("/get", cachingLevel: .memory)
        networking.fakeGET("/get", response: ["key": "value2"])
        var callbackCount = 0
        let result = try await networking.get("/get", cachingLevel: .memory)
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

    func testGETCachedFromFile() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, configuration: .default, cache: cache)
        networking.fakeGET("/get", response: ["key": "value1"])
        let _ = try await networking.get("/get", cachingLevel: .memoryAndFile)
        networking.fakeGET("/get", response: ["key": "value2"])
        var callbackCount = 0
        cache.removeAllObjects()
        let result = try await networking.get("/get", cachingLevel: .memoryAndFile)
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
