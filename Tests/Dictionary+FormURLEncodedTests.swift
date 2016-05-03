import Foundation
import XCTest

class Dictionary_FormURLEncodedTests: XCTestCase {
    func testFormatting() {
        let parameters = ["username" : "elvis", "password" : "secret"]
        let formatted = parameters.formURLEncodedFormat()

        // Here I'm checking for both because looping dictionaries can be quite inconsistent.
        if formatted == "username=elvis&password=secret" {
            XCTAssertEqual(formatted, "username=elvis&password=secret")
        } else {
            XCTAssertEqual(formatted, "password=secret&username=elvis")
        }
    }

    func testFormattingOneParameter() {
        let parameters = ["name" : "Elvis Nuñez"]
        let formatted = parameters.formURLEncodedFormat()
        XCTAssertEqual(formatted, "name=Elvis%20Nu%C3%B1ez")
    }

    func testFormattingWithEmpty() {
        let parameters = [String : AnyObject]()
        let formatted = parameters.formURLEncodedFormat()
        XCTAssertEqual(formatted, "")
    }
}
