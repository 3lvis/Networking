import Foundation
import XCTest
@testable import Networking

class PATCHTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testPATCH() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldPatch("/patch", parameters: ["username": "jameson", "password": "secret"])
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            let JSONResponse = json["json"] as? [String: String]
            XCTAssertEqual("jameson", JSONResponse?["username"])
            XCTAssertEqual("secret", JSONResponse?["password"])

            guard let headers = json["headers"] as? [String: String] else { XCTFail(); return }
            XCTAssertEqual(headers["Content-Type"], "application/json")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testPATCHWithHeaders() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldPatch("/patch")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "http://httpbin.org/patch")

            let headers = response.headers
            guard let connection = headers["Connection"] as? String else { XCTFail(); return }
            XCTAssertEqual(connection, "keep-alive")
            XCTAssertEqual(headers["Content-Type"] as? String, "application/json")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testPATCHWithIvalidPath() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldPatch("/posdddddt", parameters: ["username": "jameson", "password": "secret"])
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertEqual(response.error.code, 404)
        }
    }

    // Disabling since I don't have a reliable wait to test this works
    /*
    func testCancelPATCHWithPath() async throws {
        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        var completed = false
        let result = try await networking.oldPatch("/patch", parameters: ["username": "jameson", "password": "secret"])
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertTrue(completed)
            XCTAssertEqual(response.error.code, URLError.cancelled.rawValue)
        }

        networking.cancelPATCH("/patch")
        completed = true
    }*/
}

