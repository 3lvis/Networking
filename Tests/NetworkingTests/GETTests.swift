import Foundation
import XCTest
@testable import Networking

struct Friend: Decodable {
    let id: UUID
    let title: String
}

class GETTests: XCTestCase {
    let baseURL = "http://httpbin.org"

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
