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
        let firstResult: Result<NetworkingResponse, NetworkingError> = await networking.get("/get", cachingLevel: .memory)
        switch firstResult {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "key"), "value1")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }

        networking.fakeGET("/get", response: ["key": "value2"])

        let secondResult: Result<NetworkingResponse, NetworkingError> = await networking.get("/get", cachingLevel: .memory)
        switch secondResult {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "key"), "value2")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETCachedFromFile() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, configuration: .default, cache: cache)
        networking.fakeGET("/get", response: ["key": "value1"])
        let firstResult: Result<NetworkingResponse, NetworkingError> = await networking.get("/get", cachingLevel: .memoryAndFile)
        switch firstResult {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "key"), "value1")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }

        networking.fakeGET("/get", response: ["key": "value2"])
        let secondResult: Result<NetworkingResponse, NetworkingError> = await networking.get("/get", cachingLevel: .memoryAndFile)
        switch secondResult {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "key"), "value2")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETCachedNone() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, configuration: .default, cache: cache)
        networking.fakeGET("/get", response: ["key": "value1"])
        let firstResult: Result<NetworkingResponse, NetworkingError> = await networking.get("/get", cachingLevel: .none)
        switch firstResult {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "key"), "value1")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }

        networking.fakeGET("/get", response: ["key": "value2"])
        let secondResult: Result<NetworkingResponse, NetworkingError> = await networking.get("/get", cachingLevel: .none)
        switch secondResult {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "key"), "value2")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }
}
