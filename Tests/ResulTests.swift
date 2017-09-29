import Foundation
import XCTest

class ResultTests: XCTestCase {
    var response: HTTPURLResponse {
        let url = URL(string: "http://www.google.com")!
        let urlResponse = HTTPURLResponse(url: url, statusCode: 200)

        return urlResponse
    }

    func testJSONResultDictionary() {
        let body = ["a": "b"]
        let result = JSONResult(body: body, response: response, error: nil)
        switch result {
        case .success(let value):
            XCTAssertEqual(value.dictionaryBody.debugDescription, body.debugDescription)
        case .failure(_):
            XCTFail()
        }
    }

    func testJSONResultArray() {

    }

    func testJSONResultData() {

    }

    func testJSONResultNone() {

    }

    func testImageResultWithMalformedImage() {
        let malformedImage = "Malformed image"
        let result = ImageResult(body: malformedImage, response: response, error: nil)

        switch result {
        case .success:
            XCTFail()
        case .failure(let result):
            XCTAssertEqual(result.error.code, URLError.cannotParseResponse.rawValue)
        }
    }

    func testDataResultWithMalformedData() {
        let malformedData = "Malformed data"
        let result = DataResult(body: malformedData, response: response, error: nil)

        switch result {
        case .success:
            XCTFail()
        case .failure(let result):
            XCTAssertEqual(result.error.code, URLError.cannotParseResponse.rawValue)
        }
    }

    func testJSONResponseError() {
        let nilErrorResult = JSONResult(body: [:], response: response, error: nil)
        XCTAssertNil(nilErrorResult.error)

        let error = NSError(domain: "", code: 0, userInfo: nil)
        let errorResult = JSONResult(body: [:], response: response, error: error)
        XCTAssertNotNil(errorResult.error)
    }
}
