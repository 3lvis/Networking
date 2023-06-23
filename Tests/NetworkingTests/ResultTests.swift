import Foundation
import XCTest
@testable import Networking

class ResultTests: XCTestCase {
    var response: HTTPURLResponse {
        let url = URL(string: "http://www.google.com")!
        let urlResponse = HTTPURLResponse(url: url, statusCode: 200)

        return urlResponse
    }

    func testJSONResultDictionary() throws {
        let body = ["a": 12]
        let result = try JSONResult(body: body, response: response, error: nil)
        switch result {
        case let .success(value):
            XCTAssertEqual(value.dictionaryBody.debugDescription, body.debugDescription)
            XCTAssertEqual(value.arrayBody.debugDescription, [[String: Any]]().debugDescription)
            // XCTAssertEqual(value.data.hashValue, body.hashValue)

            switch value.json {
            case let .dictionary(_, valueBody):
                XCTAssertEqual(body.debugDescription, valueBody.debugDescription)
            case .array(_, _), .none:
                XCTFail()
            }
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testJSONResultArray() throws {
        let expectedBody = [["a": 12]]
        let result = try JSONResult(body: expectedBody, response: response, error: nil)
        switch result {
        case let .success(value):
            XCTAssertEqual(value.dictionaryBody.debugDescription, [String: Any]().debugDescription)
            XCTAssertEqual(value.arrayBody.debugDescription, expectedBody.debugDescription)
            // XCTAssertEqual(value.data.hashValue, bodyData.hashValue)

            switch value.json {
            case let .array(_, valueBody):
                XCTAssertEqual(expectedBody.debugDescription, valueBody.debugDescription)
                // XCTAssertEqual(dataBody.hashValue, expectedBody.hashValue)
            case .dictionary(_, _), .none:
                XCTFail()
            }
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testJSONResultDictionaryData() throws {
        let expectedBody = ["a": 12]
        let expectedBodyData = try JSONSerialization.data(withJSONObject: expectedBody, options: [])
        let result = try JSONResult(body: expectedBodyData, response: response, error: nil)
        switch result {
        case let .success(value):
            XCTAssertEqual(value.dictionaryBody.debugDescription, expectedBody.debugDescription)
            XCTAssertEqual(value.arrayBody.debugDescription, [[String: Any]]().debugDescription)
            XCTAssertEqual(value.data.hashValue, expectedBodyData.hashValue)

            switch value.json {
            case let .dictionary(dataBody, valueBody):
                XCTAssertEqual(dataBody.hashValue, expectedBodyData.hashValue)
                XCTAssertEqual(valueBody.debugDescription, expectedBody.debugDescription)
            case .array(_, _), .none:
                XCTFail()
            }
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testJSONResultArrayData() throws {
        let expectedBody = [["a": 12]]
        let expectedBodyData = try JSONSerialization.data(withJSONObject: expectedBody, options: [])
        let result = try JSONResult(body: expectedBodyData, response: response, error: nil)
        switch result {
        case let .success(value):
            XCTAssertEqual(value.dictionaryBody.debugDescription, [String: Any]().debugDescription)
            XCTAssertEqual(value.arrayBody.debugDescription, expectedBody.debugDescription)
            XCTAssertEqual(value.data.hashValue, expectedBodyData.hashValue)

            switch value.json {
            case let .array(dataBody, valueBody):
                XCTAssertEqual(dataBody.hashValue, expectedBodyData.hashValue)
                XCTAssertEqual(valueBody.debugDescription, expectedBody.debugDescription)
            case .dictionary(_, _), .none:
                XCTFail()
            }
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testJSONResultNone() throws {
        let result = try JSONResult(body: nil, response: response, error: nil)
        switch result {
        case let .success(value):
            XCTAssertEqual(value.dictionaryBody.debugDescription, [String: Any]().debugDescription)
            XCTAssertEqual(value.arrayBody.debugDescription, [[String: Any]]().debugDescription)
            XCTAssertEqual(value.data.hashValue, Data().hashValue)

            switch value.json {
            case .dictionary(_, _), .array:
                XCTFail()
            case .none:
                break
            }
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testImageResultWithMalformedImage() {
        let malformedImage = "Malformed image"
        let result = ImageResult(body: malformedImage, response: response, error: nil)

        switch result {
        case .success:
            XCTFail()
        case let .failure(result):
            XCTAssertEqual(result.error.code, URLError.cannotParseResponse.rawValue)
        }
    }

    func testDataResultWithMalformedData() {
        let malformedData = "Malformed data"
        let result = DataResult(body: malformedData, response: response, error: nil)

        switch result {
        case .success:
            XCTFail()
        case let .failure(result):
            XCTAssertEqual(result.error.code, URLError.cannotParseResponse.rawValue)
        }
    }

    func testJSONResponseError() throws {
        let body = [String: Any]()
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

        let nilErrorResult = try JSONResult(body: bodyData, response: response, error: nil)
        XCTAssertNil(nilErrorResult.error)

        let error = NSError(domain: "", code: 0, userInfo: nil)
        let errorResult = try JSONResult(body: bodyData, response: response, error: error)
        XCTAssertNotNil(errorResult.error)
    }
}
