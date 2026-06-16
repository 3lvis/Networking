import Foundation
import XCTest
@testable import Networking

private struct SearchParams: Encodable {
    let term: String
    let page: Int
    let exact: Bool
}

final class EncodableFormQueryIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testPOSTFormFromEncodableModel() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.post("/post", form: SearchParams(term: "swift & co", page: 2, exact: true))
        switch result {
        case let .success(response):
            let form = httpbinEchoedMap(response, "form")
            // Scalars must stringify correctly (bool -> "true", not NSNumber's "1") and special chars must survive.
            XCTAssertEqual(form["term"], "swift & co")
            XCTAssertEqual(form["page"], "2")
            XCTAssertEqual(form["exact"], "true")
            let headers = httpbinEchoedMap(response, "headers")
            XCTAssertEqual(headers["Content-Type"], "application/x-www-form-urlencoded")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETQueryFromEncodableModel() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.get("/get", query: SearchParams(term: "swift", page: 2, exact: false))
        switch result {
        case let .success(response):
            let args = httpbinEchoedMap(response, "args")
            XCTAssertEqual(args["term"], "swift")
            XCTAssertEqual(args["page"], "2")
            XCTAssertEqual(args["exact"], "false")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testDELETEQueryFromEncodableModel() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.delete("/delete", query: SearchParams(term: "swift", page: 5, exact: true))
        switch result {
        case let .success(response):
            let args = httpbinEchoedMap(response, "args")
            XCTAssertEqual(args["page"], "5")
            XCTAssertEqual(args["exact"], "true")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }
}
