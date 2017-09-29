import Foundation
import XCTest

class JSONTests: XCTestCase {
    // MARK: - Equatable

    func testEqualDictionary() {
        XCTAssertEqual(JSON(["hello":"value"]), JSON(["hello":"value"]))
        XCTAssertNotEqual(JSON(["hello1":"value"]), JSON(["hello2":"value"]))
    }

    func testEqualArray() {
        XCTAssertEqual(JSON([["hello":"value"]]), JSON([["hello":"value"]]))
        XCTAssertNotEqual(JSON([["hello1":"value"]]), JSON([["hello2":"value"]]))

        XCTAssertEqual(JSON([["hello2":"value"], ["hello1":"value"]]), JSON([["hello2":"value"], ["hello1":"value"]]))
        XCTAssertNotEqual(JSON([["hello1":"value"], ["hello2":"value"]]), JSON([["hello3":"value"], ["hello4":"value"]]))
    }

    func testEqualData() {
        let helloData = "hello".data(using: .utf8)!
        let byeData = "bye".data(using: .utf8)!
        XCTAssertEqual(JSON(helloData), JSON(helloData))
        XCTAssertNotEqual(JSON(helloData), JSON(byeData))
    }

    func testEqualNone() {
        XCTAssertEqual(JSON.none, JSON.none)
        XCTAssertNotEqual(JSON.none, JSON(["hello":"value"]))
    }

    // MARKL - Accessors

    func testDictionaryAccessor() {
        let body = ["hello":"value"]

        let json = JSON(body)
        XCTAssertEqual(json.dictionary.debugDescription, body.debugDescription)
        XCTAssertEqual(json.array.debugDescription, [[String: Any]]().debugDescription)
        XCTAssertEqual(json.data.hashValue, Data().hashValue)
    }

    func testArrayAccessor() {
        let body = [["hello":"value"]]

        let json = JSON(body)
        XCTAssertEqual(json.dictionary.debugDescription, [String: Any]().debugDescription)
        XCTAssertEqual(json.array.debugDescription, body.debugDescription)
        XCTAssertEqual(json.data.hashValue, Data().hashValue)
    }

    func testDataAccessor() {
        let body = "Data".data(using: .utf8)!

        let json = JSON(body)
        XCTAssertEqual(json.dictionary.debugDescription, [String: Any]().debugDescription)
        XCTAssertEqual(json.array.debugDescription, [[String: Any]]().debugDescription)
        XCTAssertEqual(json.data.hashValue, body.hashValue)
    }

    // MARK: - from

    func testArrayJSONFromFileNamed() {
        let result = try! JSON.from("simple_array.json", bundle: Bundle(for: JSONTests.self)) as? [[String : Any]]  ?? [[String : Any]]()
        let compared = [["id" : 1, "name" : "Hi"]]
        XCTAssertEqual(compared.count, result.count)

        // This should work but Swift is not able to compile it.
        // XCTAssertEqual(compared, result)

        XCTAssertEqual(Array(compared[0].keys), Array(result[0].keys))
        XCTAssertEqual(compared[0]["id"] as? Int, result[0]["id"] as? Int)
        XCTAssertEqual(compared[0]["name"] as? String, result[0]["name"] as? String)
    }

    func testDictionaryJSONFromFileNamed() {
        let result = try! JSON.from("simple_dictionary.json", bundle: Bundle(for: JSONTests.self)) as? [String : Any] ?? [String : Any]()
        let compared = ["id" : 1, "name" : "Hi"] as [String : Any]
        XCTAssertEqual(compared.count, result.count)
        XCTAssertEqual(Array(compared.keys), Array(result.keys))
    }

    func testFromFileNamedWithNotFoundFile() {
        var failed = false
        do {
            let _ = try JSON.from("nonexistingfile.json", bundle: Bundle(for: JSONTests.self))
        } catch ParsingError.notFound {
            failed = true
        } catch { }

        XCTAssertTrue(failed)
    }

    func testFromFileNamedWithInvalidJSON() {
        var failed = false
        do {
            let _ = try JSON.from("invalid.json", bundle: Bundle(for: JSONTests.self))
        } catch ParsingError.failed {
            failed = true
        } catch { }

        XCTAssertTrue(failed)
    }

    // MARK: - to JSON

    func testToJSON() {
        let expectation = self.expectation(description: "GET")

        guard let url = URL(string: "http://httpbin.org/get") else { return }
        let request = URLRequest(url: url)
        URLSession.shared.dataTask(with: request) { data, _, error in
            do {
                let JSON = try data?.toJSON() as? [String : Any]
                let url = JSON?["url"] as! String
                XCTAssertEqual(url, "http://httpbin.org/get")
            } catch {
                // Handle error
            }

            expectation.fulfill()
            }.resume()

        waitForExpectations(timeout: 10, handler: nil)
    }
}
