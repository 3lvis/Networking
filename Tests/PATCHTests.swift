import Foundation
import XCTest

class PATCHTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testSynchronousPATCH() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.patch("/patch", parameters: nil) { _ in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testPATCH() {
        let networking = Networking(baseURL: baseURL)
        networking.patch("/patch", parameters: ["username": "jameson", "password": "secret"]) { result in
            switch result {
            case let .success(response):
                let json = response.dictionaryBody
                let JSONResponse = json["json"] as? [String: String]
                XCTAssertEqual("jameson", JSONResponse?["username"])
                XCTAssertEqual("secret", JSONResponse?["password"])

                guard let headers = json["headers"] as? [String: String] else { XCTFail(); return }
                XCTAssertEqual(headers["Content-Type"], "application/json")
            case .failure:
                XCTFail()
            }
        }
    }

    func testPATCHWithHeaders() {
        let networking = Networking(baseURL: baseURL)
        networking.patch("/patch") { result in
            switch result {
            case let .success(response):
                let json = response.dictionaryBody
                guard let url = json["url"] as? String else { XCTFail(); return }
                XCTAssertEqual(url, "http://httpbin.org/patch")

                let headers = response.headers
                guard let connection = headers["Connection"] as? String else { XCTFail(); return }
                XCTAssertEqual(connection, "keep-alive")
                XCTAssertEqual(headers["Content-Type"] as? String, "application/json")
            case .failure:
                XCTFail()
            }
        }
    }

    func testPATCHWithIvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.patch("/posdddddt", parameters: ["username": "jameson", "password": "secret"]) { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                XCTAssertEqual(response.error.code, 404)
            }
        }
    }

    func testCancelPATCHWithPath() {
        let expectation = self.expectation(description: "testCancelPATCH")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        var completed = false
        networking.patch("/patch", parameters: ["username": "jameson", "password": "secret"]) { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                XCTAssertTrue(completed)
                XCTAssertEqual(response.error.code, URLError.cancelled.rawValue)
                expectation.fulfill()
            }
        }

        networking.cancelPATCH("/patch")
        completed = true

        waitForExpectations(timeout: 150.0, handler: nil)
    }

    func testCancelPATCHWithID() {
        let expectation = self.expectation(description: "testCancelPATCH")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        let requestID = networking.patch("/patch", parameters: ["username": "jameson", "password": "secret"]) { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                XCTAssertEqual(response.error.code, URLError.cancelled.rawValue)
                expectation.fulfill()
            }
        }

        networking.cancel(requestID)

        waitForExpectations(timeout: 150.0, handler: nil)
    }
}

