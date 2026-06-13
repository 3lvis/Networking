import Foundation
import XCTest
@testable import Networking

class GETIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testGET() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldGet("/get")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody

            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "\(TestConfig.httpbinBaseURL)/get")

            let headers = httpbinEchoedMap(json, "headers")
            let contentType = headers["Content-Type"]
            XCTAssertNil(contentType)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testGETWithFullPath() async throws {
        let networking = Networking()
        let result = try await networking.oldGet("\(TestConfig.httpbinBaseURL)/get")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody

            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "\(TestConfig.httpbinBaseURL)/get")

            let headers = httpbinEchoedMap(json, "headers")
            let contentType = headers["Content-Type"]
            XCTAssertNil(contentType)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testGETWithHeaders() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldGet("/get")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "\(TestConfig.httpbinBaseURL)/get")

            let headers = response.headers
            XCTAssertTrue((headers["Content-Type"] as? String)?.hasPrefix("application/json") ?? false)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testGETWithInvalidPath() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldGet("/invalidpath")
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertEqual(response.error.code, 404)
        }
    }

    func testStatusCodes() async throws {
        let networking = Networking(baseURL: baseURL)
        let result200 = try await networking.oldGet("/status/200")
        switch result200 {
        case let .success(response):
            XCTAssertEqual(response.statusCode, 200)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }

        var statusCode = 300
        let result300 = try await networking.oldGet("/status/\(statusCode)")
        switch result300 {
        case .success:
            XCTFail()
        case let .failure(response):
            let connectionError = NSError(domain: Networking.domain, code: statusCode, userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: statusCode)])
            XCTAssertEqual(response.error, connectionError)
        }

        statusCode = 400
        let result400 = try await networking.oldGet("/status/\(statusCode)")
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
        let result: Result<NetworkingResponse, NetworkingError> = await networking.get("/get", parameters: ["count": 25])
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get?count=25")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETWithURLEncodedParametersWithExistingQuery() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<NetworkingResponse, NetworkingError> = await networking.get("/get?accountId=123", parameters: ["userId": 5])
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get?accountId=123&userId=5")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETWithURLEncodedParametersWithPercentEncoding() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<NetworkingResponse, NetworkingError> = await networking.get("/get", parameters: ["name": "Elvis Nuñez"])
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/get?name=Elvis%20Nu%C3%B1ez")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }
}
