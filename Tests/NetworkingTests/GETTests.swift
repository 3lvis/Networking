import Foundation
import XCTest
@testable import Networking

class GETTests: XCTestCase {
    let baseURL = "http://httpbin.org"

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
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
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
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
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
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
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

    // Disabling since I don't know a reliable way to test cancellations in async/await
    /*
    func testCancelGETWithPath() async throws {
        let networking = Networking(baseURL: baseURL)
        _ = try await networking.get("/get")
        try await networking.cancelGET("/get")
        let (dataTasks, _, _) = await networking.session.tasks
        XCTAssertTrue(dataTasks.isEmpty)
    }
     */

    func testStatusCodes() async throws {
        let networking = Networking(baseURL: baseURL)
        let result200 = try await networking.get("/status/200")
        switch result200 {
        case let .success(response):
            XCTAssertEqual(response.statusCode, 200)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
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
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testGETWithURLEncodedParametersWithExistingQuery() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.get("/get?accountId=123", parameters: ["userId": 5])
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["url"] as? String, "http://httpbin.org/get?accountId=123&userId=5")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testGETWithURLEncodedParametersWithPercentEncoding() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.get("/get", parameters: ["name": "Elvis Nuñez"])
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["url"] as? String, "http://httpbin.org/get?name=Elvis Nuñez")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testGETCachedFromMemory() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, configuration: .default, cache: cache)
        networking.fakeGET("/get", response: ["key": "value1"])
        let firstResult = try await networking.get("/get", cachingLevel: .memory)
        switch firstResult {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["key"] as? String, "value1")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }

        networking.fakeGET("/get", response: ["key": "value2"])

        let secondResult = try await networking.get("/get", cachingLevel: .memory)
        switch secondResult {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["key"] as? String, "value2")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testGETCachedFromFile() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, configuration: .default, cache: cache)
        networking.fakeGET("/get", response: ["key": "value1"])
        let firstResult = try await networking.get("/get", cachingLevel: .memoryAndFile)
        switch firstResult {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["key"] as? String, "value1")
        case .failure(let response):
            XCTFail("Error: \(response.error)")
        }

        networking.fakeGET("/get", response: ["key": "value2"])
        let secondResult = try await networking.get("/get", cachingLevel: .memoryAndFile)
        switch secondResult {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["key"] as? String, "value2")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testGETCachedNone() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, configuration: .default, cache: cache)
        networking.fakeGET("/get", response: ["key": "value1"])
        let firstResult = try await networking.get("/get", cachingLevel: .none)
        switch firstResult {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["key"] as? String, "value1")
        case .failure(let response):
            XCTFail("Error: \(response.error)")
        }

        networking.fakeGET("/get", response: ["key": "value2"])
        let secondResult = try await networking.get("/get", cachingLevel: .none)
        switch secondResult {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["key"] as? String, "value2")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

}
