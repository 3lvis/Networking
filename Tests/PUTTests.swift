import Foundation
import XCTest

class PUTTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testSynchronousPUT() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.put("/put", parameters: nil) { _ in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testPUT() {
        let networking = Networking(baseURL: baseURL)
        networking.put("/put", parameters: ["username": "jameson", "password": "secret"]) { result in
            switch result {
            case .success(let json, _):
                let json = json.dictionary
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

    func testPUTWithHeaders() {
        let networking = Networking(baseURL: baseURL)
        networking.put("/put") { result in
            switch result {
            case .success(let json, let response):
                let json = json.dictionary
                guard let url = json["url"] as? String else { XCTFail(); return }
                XCTAssertEqual(url, "http://httpbin.org/put")

                let headers = response.allHeaderFields
                guard let connection = headers["Connection"] as? String else { XCTFail(); return }
                XCTAssertEqual(connection, "keep-alive")
                XCTAssertEqual(headers["Content-Type"] as? String, "application/json")
            case .failure:
                XCTFail()
            }
        }
    }

    func testPUTWithIvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.put("/posdddddt", parameters: ["username": "jameson", "password": "secret"]) { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(_, _, let error):
                XCTAssertEqual(error.code, 404)
            }
        }
    }

    func testFakePUT() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/story", response: [["name": "Elvis"]])

        networking.put("/story", parameters: ["username": "jameson", "password": "secret"]) { result in
            switch result {
            case .success(let json, _):
                let json = json.array
                let value = json[0]["name"] as? String
                XCTAssertEqual(value, "Elvis")
            case .failure:
                XCTFail()
            }
        }
    }

    func testFakePUTWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/story", response: nil, statusCode: 401)

        networking.put("/story", parameters: nil) { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(_, _, let error):
                XCTAssertEqual(error.code, 401)
            }
        }
    }

    func testFakePUTUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/entries", fileName: "entries.json", bundle: Bundle(for: PUTTests.self))

        networking.put("/entries", parameters: nil) { result in
            switch result {
            case .success(let json, _):
                let json = json.array
                let entry = json[0]
                let value = entry["title"] as? String
                XCTAssertEqual(value, "Entry 1")
            case .failure:
                XCTFail()
            }
        }
    }

    func testCancelPUTWithPath() {
        let expectation = self.expectation(description: "testCancelPUT")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        var completed = false
        networking.put("/put", parameters: ["username": "jameson", "password": "secret"]) { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(_, _, let error):
                XCTAssertTrue(completed)
                XCTAssertEqual(error.code, URLError.cancelled.rawValue)
                expectation.fulfill()
            }
        }

        networking.cancelPUT("/put")
        completed = true

        waitForExpectations(timeout: 150.0, handler: nil)
    }

    func testCancelPUTWithID() {
        let expectation = self.expectation(description: "testCancelPUT")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        let requestID = networking.put("/put", parameters: ["username": "jameson", "password": "secret"]) { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(_, _, let error):
                XCTAssertEqual(error.code, URLError.cancelled.rawValue)
                expectation.fulfill()
            }
        }

        networking.cancel(with: requestID)

        waitForExpectations(timeout: 150.0, handler: nil)
    }
}
