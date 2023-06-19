import Foundation
import XCTest
@testable import Networking

class Dictionary_FormURLEncodedTests: XCTestCase {

    func testFormatting() throws {
        let parameters = ["username": "elvis", "password": "secret"]
        let formatted = try parameters.urlEncodedString()

        // Here I'm checking for both because looping dictionaries can be quite inconsistent.
        if formatted == "username=elvis&password=secret" {
            XCTAssertEqual(formatted, "username=elvis&password=secret")
        } else {
            XCTAssertEqual(formatted, "password=secret&username=elvis")
        }
    }

    func testFormattingOneParameter() throws {
        let parameters = ["name": "Elvis Nuñez"]
        let formatted = try parameters.urlEncodedString()
        XCTAssertEqual(formatted, "name=Elvis%20Nu%C3%B1ez")
    }

    func testFormattingDate() throws {
        let parameters = ["date": "2016-11-02T13:55:28+01:00"]
        let formatted = try parameters.urlEncodedString()
        XCTAssertEqual(formatted, "date=2016-11-02T13%3A55%3A28%2B01%3A00")
    }

    func testFormattingWithEmpty() throws {
        let parameters = [String: Any]()
        let formatted = try parameters.urlEncodedString()
        XCTAssertEqual(formatted, "")
    }
}
