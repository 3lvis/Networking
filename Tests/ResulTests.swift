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
        let bodyData = try! JSONSerialization.data(withJSONObject: body, options: [])
        let result = JSONResult(body: bodyData, response: response, error: nil)
        switch result {
        case .success(let value):
            XCTAssertEqual(value.dictionaryBody.debugDescription, body.debugDescription)
            XCTAssertEqual(value.arrayBody.debugDescription, [[String: Any]]().debugDescription)
            XCTAssertEqual(value.data.hashValue, Data().hashValue)

            switch value.json {
            case .dictionary(_, let valueBody):
                XCTAssertEqual(body.debugDescription, valueBody.debugDescription)
            case .array(_, _), .none:
                XCTFail()
            }
        case .failure(_):
            XCTFail()
        }
    }

    func testJSONResultArray() {
        let body = [["a": "b"]]
        let bodyData = try! JSONSerialization.data(withJSONObject: body, options: [])
        let result = JSONResult(body: bodyData, response: response, error: nil)
        switch result {
        case .success(let value):
            XCTAssertEqual(value.dictionaryBody.debugDescription, [String: Any]().debugDescription)
            XCTAssertEqual(value.arrayBody.debugDescription, body.debugDescription)
            XCTAssertEqual(value.data.hashValue, Data().hashValue)

            switch value.json {
            case .array(_, let valueBody):
                XCTAssertEqual(body.debugDescription, valueBody.debugDescription)
            case .dictionary(_, _), .none:
                XCTFail()
            }
        case .failure(_):
            XCTFail()
        }
    }

    func testJSONResultNone() {
        let body = "Invalid"
        let bodyData = try! JSONSerialization.data(withJSONObject: body, options: [])
        let result = JSONResult(body: bodyData, response: response, error: nil)
        switch result {
        case .success(let value):
            XCTAssertEqual(value.dictionaryBody.debugDescription, [String: Any]().debugDescription)
            XCTAssertEqual(value.arrayBody.debugDescription, [[String: Any]]().debugDescription)
            XCTAssertEqual(value.data.hashValue, Data().hashValue)

            switch value.json {
            case .dictionary(_, _), .array(_, _):
                XCTFail()
            case .none:
                break
            }
        case .failure(_):
            XCTFail()
        }
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
        let body = [String: Any]()
        let bodyData = try! JSONSerialization.data(withJSONObject: body, options: [])

        let nilErrorResult = JSONResult(body: bodyData, response: response, error: nil)
        XCTAssertNil(nilErrorResult.error)

        let error = NSError(domain: "", code: 0, userInfo: nil)
        let errorResult = JSONResult(body: bodyData, response: response, error: error)
        XCTAssertNotNil(errorResult.error)
    }
}

