import Foundation
import XCTest

class HTTPRequestTests: XCTestCase {
    let baseURL = "http://httpbin.org"
}

// MARK: GET

extension HTTPRequestTests {
    func testSynchronousGET() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.GET("/get", completion: { JSON, error in
            synchronous = true
        })

        XCTAssertTrue(synchronous)
    }

    func testGET() {
        let networking = Networking(baseURL: baseURL)
        networking.GET("/get", completion: { JSON, error in
            let JSON = JSON as! [String : AnyObject]
            let url = JSON["url"] as! String
            XCTAssertEqual(url, "http://httpbin.org/get")
        })
    }

    func testCancelGET() {
        let expectation = expectationWithDescription("testCancelGET")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.GET("/get", completion: { JSON, error in
            let canceledCode = error?.code == -999
            XCTAssertTrue(canceledCode)

            expectation.fulfill()
        })

        networking.cancelGET("/get")

        waitForExpectationsWithTimeout(3.0, handler: nil)
    }

    func testGETWithInvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.GET("/invalidpath", completion: { JSON, error in
            if let JSON: AnyObject = JSON {
                fatalError("JSON not nil: \(JSON)")
            } else {
                XCTAssertNotNil(error)
            }
        })
    }

    func testGETStubs() {
        let networking = Networking(baseURL: baseURL)

        networking.stubGET("/stories", response: ["name" : "Elvis"])

        networking.GET("/stories", completion: { JSON, error in
            let JSON = JSON as! [String : String]
            let value = JSON["name"]
            XCTAssertEqual(value!, "Elvis")
        })
    }

    func testGETStubsUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.stubGET("/entries", fileName: "entries.json", bundle: NSBundle(forClass: self.classForKeyedArchiver!))

        networking.GET("/entries", completion: { JSON, error in
            let JSON = JSON as! [[String : AnyObject]]
            let entry = JSON[0]
            let value = entry["title"] as! String
            XCTAssertEqual(value, "Entry 1")
        })
    }
}

// MARK: POST

extension HTTPRequestTests {
    func testSynchronousPOST() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post", parameters: nil) { JSON, error in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testPOST() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            XCTAssertNotNil(JSON!, "JSON not nil")
            XCTAssertNil(error, "Error")
        }
    }

    func testCancelPOST() {
        let expectation = expectationWithDescription("testCancelPOST")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.POST("/post", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            let canceledCode = error?.code == -999
            XCTAssertTrue(canceledCode)

            expectation.fulfill()
        }

        networking.cancelPOST("/post")

        waitForExpectationsWithTimeout(3.0, handler: nil)
    }

    func testPOSTWithIvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/posdddddt", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            XCTAssertNotNil(error)
            XCTAssertNil(JSON)
        }
    }

    func testPOSTStubs() {
        let networking = Networking(baseURL: baseURL)

        networking.stubPOST("/story", response: [["name" : "Elvis"]])

        networking.POST("/story", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            let JSON = JSON as! [[String : String]]
            let value = JSON[0]["name"]
            XCTAssertEqual(value!, "Elvis")
        }
    }
}
