import Foundation
import XCTest

class JSONTests: XCTestCase {
    func testDictionary() {
        XCTAssertEqual(JSON(["hello":"value"]), JSON(["hello":"value"]))
        XCTAssertNotEqual(JSON(["hello1":"value"]), JSON(["hello2":"value"]))
    }

    func testArray() {
        XCTAssertEqual(JSON([["hello":"value"]]), JSON([["hello":"value"]]))
        XCTAssertNotEqual(JSON([["hello1":"value"]]), JSON([["hello2":"value"]]))

        XCTAssertEqual(JSON([["hello2":"value"], ["hello1":"value"]]), JSON([["hello2":"value"], ["hello1":"value"]]))
        XCTAssertNotEqual(JSON([["hello1":"value"], ["hello2":"value"]]), JSON([["hello3":"value"], ["hello4":"value"]]))
    }

    func testNone() {
        XCTAssertEqual(JSON.none, JSON.none)
        XCTAssertNotEqual(JSON.none, JSON(["hello":"value"]))
    }
}
