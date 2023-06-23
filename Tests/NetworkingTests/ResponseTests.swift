import XCTest
@testable import Networking

class ResponseTest: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testDataAccessor() async throws {
        let networking = Networking(baseURL: baseURL)
        let expectedBody = ["user-agent": "hi mom!"]
        networking.headerFields = expectedBody
        let result = try await networking.get("/user-agent")
        switch result {
        case let .success(response):
            XCTAssertEqual(try response.data.toStringStringDictionary().debugDescription, expectedBody.debugDescription)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }
}
