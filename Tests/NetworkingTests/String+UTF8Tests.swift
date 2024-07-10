import Foundation
import XCTest
@testable import Networking

class String_UTF8Tests: XCTestCase {

    func testEncodeUTF8WithNorwegianCharacters() {
        let encodedString = "døgnvillburgere.jpg".encodeUTF8()
        XCTAssertEqual(encodedString, "d%C3%B8gnvillburgere.jpg")
    }

    func testEncodeUTF8WithSpaces() {
        let encodedString = "a file with spaces.jpg".encodeUTF8()
        XCTAssertEqual(encodedString, "a%20file%20with%20spaces.jpg")
    }

    func testEncodeUTF8WithSpecialCharacters() {
        let encodedString = "file@name#with$special&chars.jpg".encodeUTF8()
        XCTAssertEqual(encodedString, "file@name%23with$special&chars.jpg")
    }

    func testEncodeUTF8WithSlashes() {
        let encodedString = "path/to/file.jpg".encodeUTF8()
        XCTAssertEqual(encodedString, "path/to/file.jpg")
    }

    func testEncodeUTF8WithUnicodeCharacters() {
        let encodedString = "文件.jpg".encodeUTF8()
        XCTAssertEqual(encodedString, "%E6%96%87%E4%BB%B6.jpg")
    }

    func testEncodeUTF8WithValidURL() {
        let encodedString = "https://example.com/file.jpg".encodeUTF8()
        XCTAssertEqual(encodedString, "https://example.com/file.jpg")
    }

    func testEncodeUTF8WithFragment() {
        let encodedString = "file#section.jpg".encodeUTF8()
        XCTAssertEqual(encodedString, "file%23section.jpg")
    }

    func testEncodeUTF8WithMultipleSpecialCharacters() {
        let encodedString = "file@name with spaces & special#chars$.jpg".encodeUTF8()
        XCTAssertEqual(encodedString, "file@name%20with%20spaces%20&%20special%23chars$.jpg")
    }
}
