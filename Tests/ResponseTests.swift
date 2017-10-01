import XCTest

class ResponseTest: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testDataAccessor() {
        let networking = Networking(baseURL: baseURL)
        let expectedBody = ["user-agent": "hi mom!"]
        let expectedData = try! JSONSerialization.data(withJSONObject: expectedBody, options: [])
        networking.headerFields = expectedBody
        networking.get("/user-agent") { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.data.hashValue, expectedData.hashValue)
            case .failure:
                XCTFail()
            }
        }
    }
}
