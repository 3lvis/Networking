import Foundation
import XCTest

class String_UTF8Tests: XCTestCase {

    func testEncodeUTF8WithNorwegianCharacters() {
        let encodedString = "døgnvillburgere.jpg".encodeUTF8()
        XCTAssertEqual(encodedString, "d%C3%B8gnvillburgere.jpg")
    }
}
