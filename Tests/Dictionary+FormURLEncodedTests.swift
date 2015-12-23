import Foundation
import XCTest

class Dictionary_FormURLEncodedTests: XCTestCase {
    func testFormatting() {
        let parameters = ["password" : "secret", "username" : "elvis"]
        let formatted = parameters.formURLEncodedFormat()
        XCTAssertEqual(formatted, "username=elvis&password=secret")
    }

    func testFormattingOneParameter() {
        let parameters = ["password" : "secret"]
        let formatted = parameters.formURLEncodedFormat()
        XCTAssertEqual(formatted, "password=secret")
    }

    func testFormattingWithEmpty() {
        let parameters = [String : AnyObject]()
        let formatted = parameters.formURLEncodedFormat()
        XCTAssertEqual(formatted, "")
    }
}
