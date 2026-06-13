import Foundation
import XCTest
@testable import Networking

struct Friend: Decodable {
    let id: UUID
    let title: String
}

class GETTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    // I'm not sure how it implement this, since I need a service that returns a faulty status code, meaning not 2XX, and at the same time it returns a JSON response.
    func testGETWithInvalidPathAndJSONError() {
    }

    // Disabling since I don't know a reliable way to test cancellations in async/await
    /*
    func testCancelGETWithPath() async throws {
        let networking = Networking(baseURL: baseURL)
        _ = try await networking.oldGet("/get")
        try await networking.cancelGET("/get")
        let (dataTasks, _, _) = await networking.session.tasks
        XCTAssertTrue(dataTasks.isEmpty)
    }
     */

//    func testGETWithURLEncodedParameters() async throws {
//        let networking = Networking(baseURL: baseURL)
//        let result = try await networking.oldGet("/get", parameters: ["count": 25])
//        switch result {
//        case let .success(response):
//            let json = response.dictionaryBody
//            XCTAssertEqual(json["url"] as? String, "http://httpbin.org/get?count=25")
//        case let .failure(response):
//            XCTFail(response.error.localizedDescription)
//        }
//    }

//    func testGETWithURLEncodedParametersWithExistingQuery() async throws {
//        let networking = Networking(baseURL: baseURL)
//        let result = try await networking.oldGet("/get?accountId=123", parameters: ["userId": 5])
//        switch result {
//        case let .success(response):
//            let json = response.dictionaryBody
//            XCTAssertEqual(json["url"] as? String, "http://httpbin.org/get?accountId=123&userId=5")
//        case let .failure(response):
//            XCTFail(response.error.localizedDescription)
//        }
//    }

//    func testGETWithURLEncodedParametersWithPercentEncoding() async throws {
//        let networking = Networking(baseURL: baseURL)
//        let result = try await networking.oldGet("/get", parameters: ["name": "Elvis Nuñez"])
//        switch result {
//        case let .success(response):
//            let json = response.dictionaryBody
//            XCTAssertEqual(json["url"] as? String, "http://httpbin.org/get?name=Elvis Nuñez")
//        case let .failure(response):
//            XCTFail(response.error.localizedDescription)
//        }
//    }

    func testGETCachedFromMemory() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, configuration: .default, cache: cache)
        networking.fakeGET("/get", response: ["key": "value1"])
        let firstResult = try await networking.oldGet("/get", cachingLevel: .memory)
        switch firstResult {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["key"] as? String, "value1")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }

        networking.fakeGET("/get", response: ["key": "value2"])

        let secondResult = try await networking.oldGet("/get", cachingLevel: .memory)
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
        let firstResult = try await networking.oldGet("/get", cachingLevel: .memoryAndFile)
        switch firstResult {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["key"] as? String, "value1")
        case .failure(let response):
            XCTFail("Error: \(response.error)")
        }

        networking.fakeGET("/get", response: ["key": "value2"])
        let secondResult = try await networking.oldGet("/get", cachingLevel: .memoryAndFile)
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
        let firstResult = try await networking.oldGet("/get", cachingLevel: .none)
        switch firstResult {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["key"] as? String, "value1")
        case .failure(let response):
            XCTFail("Error: \(response.error)")
        }

        networking.fakeGET("/get", response: ["key": "value2"])
        let secondResult = try await networking.oldGet("/get", cachingLevel: .none)
        switch secondResult {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["key"] as? String, "value2")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }
}
