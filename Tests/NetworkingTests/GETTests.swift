import Foundation
import XCTest

@testable import Networking

struct Friend: Decodable {
    let id: UUID
    let title: String
}

class GETTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testGETCachedFromMemory() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, configuration: .default, cache: cache)
        await networking.fakeGET("/get", response: ["key": "value1"])
        let firstResult: Result<JSONResponse, NetworkingError> = await networking.get("/get", cachingLevel: .memory)
        switch firstResult {
        case .success(let response):
            XCTAssertEqual(response.body.string(for: "key"), "value1")
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }

        await networking.fakeGET("/get", response: ["key": "value2"])

        let secondResult: Result<JSONResponse, NetworkingError> = await networking.get("/get", cachingLevel: .memory)
        switch secondResult {
        case .success(let response):
            XCTAssertEqual(response.body.string(for: "key"), "value2")
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETCachedFromFile() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, configuration: .default, cache: cache)
        await networking.fakeGET("/get", response: ["key": "value1"])
        let firstResult: Result<JSONResponse, NetworkingError> = await networking.get(
            "/get", cachingLevel: .memoryAndFile)
        switch firstResult {
        case .success(let response):
            XCTAssertEqual(response.body.string(for: "key"), "value1")
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }

        await networking.fakeGET("/get", response: ["key": "value2"])
        let secondResult: Result<JSONResponse, NetworkingError> = await networking.get(
            "/get", cachingLevel: .memoryAndFile)
        switch secondResult {
        case .success(let response):
            XCTAssertEqual(response.body.string(for: "key"), "value2")
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETCachedNone() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, configuration: .default, cache: cache)
        await networking.fakeGET("/get", response: ["key": "value1"])
        let firstResult: Result<JSONResponse, NetworkingError> = await networking.get("/get", cachingLevel: .none)
        switch firstResult {
        case .success(let response):
            XCTAssertEqual(response.body.string(for: "key"), "value1")
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }

        await networking.fakeGET("/get", response: ["key": "value2"])
        let secondResult: Result<JSONResponse, NetworkingError> = await networking.get("/get", cachingLevel: .none)
        switch secondResult {
        case .success(let response):
            XCTAssertEqual(response.body.string(for: "key"), "value2")
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }
}
