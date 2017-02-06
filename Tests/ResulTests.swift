import Foundation
import XCTest

class ResultTests: XCTestCase {
    func testImageResultWithMalformedImage() {
        let url = URL(string: "http://www.google.com")!
        let urlResponse = HTTPURLResponse(url: url, statusCode: 200)
        let malformedImage = "Malformed image"
        let result = ImageResult(body: malformedImage, response: urlResponse, error: nil)

        switch result {
        case .success:
            XCTFail()
        case .failure(let result):
            XCTAssertEqual(result.error.code, URLError.cannotParseResponse.rawValue)
        }
    }

    func testDataResultWithMalformedData() {
        let url = URL(string: "http://www.google.com")!
        let urlResponse = HTTPURLResponse(url: url, statusCode: 200)
        let malformedData = "Malformed data"
        let result = DataResult(body: malformedData, response: urlResponse, error: nil)

        switch result {
        case .success:
            XCTFail()
        case .failure(let result):
            XCTAssertEqual(result.error.code, URLError.cannotParseResponse.rawValue)
        }
    }

    func testJSONResponseError() {
        let url = URL(string: "http://www.google.com")!
        let urlResponse = HTTPURLResponse(url: url, statusCode: 200)

        let nilErrorResult = JSONResult(body: [:], response: urlResponse, error: nil)
        XCTAssertNil(nilErrorResult.error)

        let error = NSError(domain: "", code: 0, userInfo: nil)
        let errorResult = JSONResult(body: [:], response: urlResponse, error: error)
        XCTAssertNotNil(errorResult.error)
    }
}
