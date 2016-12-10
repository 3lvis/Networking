//
//  ResultTests.swift
//
//  Copyright (c) 2014-2016 Alamofire Software Foundation (http://alamofire.org/)
//  Copyright (c) 2016 Elvis Nuñez
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import XCTest

class ResultTestCase: XCTestCase {
    let error = NSError(domain: Networking.domain, code: 404, userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: 404)])

    // MARK: - Is Success Tests

    func testThatIsSuccessPropertyReturnsTrueForSuccessCase() {
        // Given, When
        let result = Result<[String: Int]>.success(["id": 1], [:])

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true for success case")
    }

    func testThatIsSuccessPropertyReturnsFalseForFailureCase() {
        // Given, When
        let result = Result<String>.failure(error, nil)

        // Then
        XCTAssertFalse(result.isSuccess, "result is success should be true for failure case")
    }

    // MARK: - Is Failure Tests

    func testThatIsFailurePropertyReturnsFalseForSuccessCase() {
        // Given, When
        let result = Result<[String: Int]>.success(["id": 1], [:])

        // Then
        XCTAssertFalse(result.isFailure, "result is failure should be false for success case")
    }

    func testThatIsFailurePropertyReturnsTrueForFailureCase() {
        // Given, When
        let result = Result<String>.failure(error, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true for failure case")
    }

    // MARK: - Value Tests

    func testThatValuePropertyReturnsValueForSuccessCase() {
        // Given, When
        let result = Result<[String: Int]>.success(["id": 1], [:])

        // Then
        if let resultValue = result.value {
            XCTAssertEqual(resultValue, ["id": 1])
        } else {
            XCTFail()
        }
    }

    func testThatValuePropertyReturnsNilForFailureCase() {
        // Given, When
        let result = Result<String>.failure(error, nil)

        // Then
        XCTAssertNil(result.value, "result value should be nil for failure case")
    }

    // MARK: - Error Tests

    func testThatErrorPropertyReturnsNilForSuccessCase() {
        // Given, When
        let result = Result<[String: Int]>.success(["id": 1], [:])

        // Then
        XCTAssertTrue(result.error == nil, "result error should be nil for success case")
    }

    func testThatErrorPropertyReturnsErrorForFailureCase() {
        // Given, When
        let result = Result<String>.failure(error, nil)

        // Then
        XCTAssertTrue(result.error != nil, "result error should not be nil for failure case")
    }

    // MARK: - Description Tests

    func testThatDescriptionStringMatchesExpectedValueForSuccessCase() {
        // Given, When
        let result = Result<[String: Int]>.success(["id": 1], [:])

        // Then
        XCTAssertEqual(result.description, "SUCCESS", "result description should match expected value for success case")
    }

    func testThatDescriptionStringMatchesExpectedValueForFailureCase() {
        // Given, When
        let result = Result<String>.failure(error, nil)

        // Then
        XCTAssertEqual(result.description, "FAILURE", "result description should match expected value for failure case")
    }

    // MARK: - Debug Description Tests

    func testThatDebugDescriptionStringMatchesExpectedValueForSuccessCase() {
        // Given, When
        let result = Result<[String: Int]>.success(["id": 1], [:])

        // Then
        XCTAssertEqual(
            result.debugDescription,
            "SUCCESS: ([\"id\": 1], [:])",
            "result debug description should match expected value for success case"
        )
    }

    func testThatDebugDescriptionStringMatchesExpectedValueForFailureCase() {
        // Given, When
        let result = Result<String>.failure(error, nil)

        // Then
        XCTAssertEqual(
            result.debugDescription,
            "FAILURE: (Error Domain=com.3lvis.networking Code=404 \"not found\" UserInfo={NSLocalizedDescription=not found}, nil)",
            "result debug description should match expected value for failure case"
        )
    }
}
