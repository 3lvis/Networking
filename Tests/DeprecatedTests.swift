import Foundation
import XCTest

class DeprecatedTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testGET() {
        let networking = Networking(baseURL: baseURL)
        networking.oldGET("/get") { json, error in
            print(String(data: try! JSONSerialization.data(withJSONObject: json!, options: .prettyPrinted), encoding: .utf8)!)
            guard let json = json as? [String: Any] else { XCTFail(); return }

            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "http://httpbin.org/get")

            guard let headers = json["headers"] as? [String: String] else { XCTFail(); return }
            let contentType = headers["Content-Type"]
            XCTAssertNil(contentType)
        }
    }

    func testGETWithHeaders() {
        let networking = Networking(baseURL: baseURL)
        networking.oldGET("/get") { json, headers, error in
            guard let json = json as? [String: Any] else { XCTFail(); return }
            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "http://httpbin.org/get")

            guard let connection = headers["Connection"] as? String else { XCTFail(); return }
            XCTAssertEqual(connection, "keep-alive")
            XCTAssertEqual(headers["Content-Type"] as? String, "application/json")
        }
    }

    func testGETWithInvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.oldGET("/invalidpath") { json, error in
            XCTAssertNil(json)
            XCTAssertEqual(error?.code, 404)
        }
    }

    // TODO: I'm not sure how it implement this, since I need a service that returns a faulty
    // status code, meaning not 2XX, and at the same time it returns a JSON response.
    func testGETWithInvalidPathAndJSONError() {
    }
}
