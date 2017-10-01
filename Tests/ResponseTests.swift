import XCTest

class ResponseTest: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testDataAccessor() {
        let networking = Networking(baseURL: baseURL)
        let expectedBody = ["user-agent": "hi mom!"]
        networking.headerFields = expectedBody
        networking.get("/user-agent") { result in
            switch result {
            case let .success(response):
                XCTAssertEqual(response.data.toStringStringDictionary().debugDescription, expectedBody.debugDescription)
            case .failure:
                XCTFail()
            }
        }
    }
}
