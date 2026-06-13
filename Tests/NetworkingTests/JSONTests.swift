import Foundation
import XCTest
@testable import Networking

class JSONTests: XCTestCase {
    func testArrayJSONFromFileNamed() throws {
        let result = try FileManager.json(from: "simple_array.json", bundle: .module) as? [[String: Any]] ?? [[String: Any]]()
        let compared = [["id": 1, "name": "Hi"] as [String : Any]]
        
        XCTAssertEqual(compared.count, result.count)

        // This should work but Swift is not able to compile it.
        // XCTAssertEqual(compared, result)

        let comparedKeys = Array(compared[0].keys).sorted()
        let resultKeys = Array(result[0].keys).sorted()
        XCTAssertEqual(comparedKeys, resultKeys)
        XCTAssertEqual(compared[0]["id"] as? Int, result[0]["id"] as? Int)
        XCTAssertEqual(compared[0]["name"] as? String, result[0]["name"] as? String)
    }

    func testDictionaryJSONFromFileNamed() throws {
        let result = try FileManager.json(from: "simple_dictionary.json", bundle: .module) as? [String: Any] ?? [String: Any]()
        let compared = ["id": 1, "name": "Hi"] as [String: Any]
        XCTAssertEqual(compared.count, result.count)
        XCTAssertEqual(Array(compared.keys).sorted(), Array(result.keys).sorted())
    }

    func testFromFileNamedWithNotFoundFile() {
        var failed = false
        do {
            _ = try FileManager.json(from: "nonexistingfile.json", bundle: .module)
        } catch ParsingError.notFound {
            failed = true
        } catch {}

        XCTAssertTrue(failed)
    }

    func testFromFileNamedWithInvalidJSON() {
        do {
            _ = try FileManager.json(from: "invalid.json", bundle: .module)
            XCTFail()
        } catch let error as NSError {
            XCTAssertEqual(error.code, 3840)
        }
    }
}
