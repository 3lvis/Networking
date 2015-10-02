import Foundation
import XCTest

class Tests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testGET() {
        var success = false

        let networking = Networking(baseURL: baseURL)
        networking.GET("/get", completion: { JSON, error in
            if let JSON = JSON as? [String : AnyObject] {
                let url = JSON["url"] as! String
                XCTAssertEqual(url, "http://httpbin.org/get")
                success = true
            }
        })

        XCTAssertTrue(success)
    }

    func testGETWithInvalidPath() {
        var success = false

        let networking = Networking(baseURL: baseURL)
        networking.GET("invalidpath", completion: { JSON, error in
            if let JSON: AnyObject = JSON {
                fatalError("JSON not nil: \(JSON)")
            } else {
                if let error = error {
                    XCTAssertNotNil(error)
                    success = true
                }
            }
        })

        XCTAssertTrue(success)
    }

    func testGETStubs() {
        Networking.stubGET("/stories", response: ["name" : "Elvis"])

        var success = false
        let networking = Networking(baseURL: baseURL)
        networking.GET("/stories", completion: { JSON, error in
            if let JSON = JSON as? [String : String] {
                let value = JSON["name"]
                XCTAssertEqual(value!, "Elvis")
                success = true
            }
        })

        XCTAssertTrue(success)
    }

    func testGETStubsUsingFile() {
        Networking.stubGET("/entries", fileName: "entries.json", bundle: NSBundle(forClass: self.classForKeyedArchiver!))

        var success = false
        let networking = Networking(baseURL: baseURL)
        networking.GET("/entries", completion: { JSON, error in
            if let JSON = JSON as? [[String : AnyObject]] {
                let entry = JSON[0]
                let value = entry["title"] as! String
                XCTAssertEqual(value, "Entry 1")
                success = true
            }
        })
        
        XCTAssertTrue(success)
    }

    func testPOST() {
        var success = false
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post", params: ["username":"jameson", "password":"password"]) { JSON, error in
            if let JSON = JSON {
                XCTAssertNotNil(JSON, "JSON not nil")
                XCTAssertNil(error, "Error")
                success = true
            }
        }

        XCTAssertTrue(success)
    }

    func testPOSTWithIvalidPath() {
        var success = false
        let networking = Networking(baseURL: baseURL)
        networking.POST("/posdddddt", params: ["username":"jameson", "password":"password"]) { JSON, error in
            if let error = error {
                XCTAssertNotNil(error)
                XCTAssertNil(JSON)
                success = true
            }
        }

        XCTAssertTrue(success)
    }

    func testPOSTStubs() {
        Networking.stubPOST("/story", response: [["name" : "Elvis"]])

        var success = false
        let networking = Networking(baseURL: baseURL)
        networking.POST("/story", params: ["username":"jameson", "password":"password"]) { JSON, error in
            if let JSON = JSON as? [[String : String]] {
                let value = JSON[0]["name"]
                XCTAssertEqual(value!, "Elvis")
                success = true
            }
        }

        XCTAssertTrue(success)
    }

    func testURLForPath() {
        let networking = Networking(baseURL: baseURL)
        let url = networking.urlForPath("/hello")
        XCTAssertEqual(url.absoluteString, "http://httpbin.org/hello")
    }
}
