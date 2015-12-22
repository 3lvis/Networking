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

    func testStatusCodes() {
        let networking = Networking(baseURL: baseURL)

        networking.GET("/status/200") { JSON, error in
            XCTAssertNil(JSON)
            XCTAssertNil(error)
        }

        var statusCode = 300
        networking.GET("/status/\(statusCode)") { JSON, error in
            XCTAssertNil(JSON)
            let connectionError = NSError(domain: Networking.ErrorDomain, code: statusCode, userInfo: [NSLocalizedDescriptionKey : NSHTTPURLResponse.localizedStringForStatusCode(statusCode)])
            XCTAssertEqual(error, connectionError)
        }

        statusCode = 400
        networking.GET("/status/\(statusCode)") { JSON, error in
            XCTAssertNil(JSON)
            let connectionError = NSError(domain: Networking.ErrorDomain, code: statusCode, userInfo: [NSLocalizedDescriptionKey : NSHTTPURLResponse.localizedStringForStatusCode(statusCode)])
            XCTAssertEqual(error, connectionError)
        }
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

// MARK: PUT

extension HTTPRequestTests {
    func testSynchronousPUT() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.PUT("/put", parameters: nil) { JSON, error in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testPUT() {
        let networking = Networking(baseURL: baseURL)
        networking.PUT("/put", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            XCTAssertNotNil(JSON!, "JSON not nil")
            XCTAssertNil(error, "Error")
        }
    }

    func testCancelPUT() {
        let expectation = expectationWithDescription("testCancelPUT")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.PUT("/put", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            let canceledCode = error?.code == -999
            XCTAssertTrue(canceledCode)

            expectation.fulfill()
        }

        networking.cancelPUT("/put")

        waitForExpectationsWithTimeout(3.0, handler: nil)
    }

    func testPUTWithIvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.PUT("/posdddddt", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            XCTAssertNotNil(error)
            XCTAssertNil(JSON)
        }
    }

    func testPUTStubs() {
        let networking = Networking(baseURL: baseURL)

        networking.stubPUT("/story", response: [["name" : "Elvis"]])

        networking.PUT("/story", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            let JSON = JSON as! [[String : String]]
            let value = JSON[0]["name"]
            XCTAssertEqual(value!, "Elvis")
        }
    }
}

// MARK: DELETE

extension HTTPRequestTests {
    func testSynchronousDELETE() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.DELETE("/delete", completion: { JSON, error in
            synchronous = true
        })

        XCTAssertTrue(synchronous)
    }

    func testDELETE() {
        let networking = Networking(baseURL: baseURL)
        networking.DELETE("/delete", completion: { JSON, error in
            let JSON = JSON as! [String : AnyObject]
            let url = JSON["url"] as! String
            XCTAssertEqual(url, "http://httpbin.org/delete")
        })
    }

    func testCancelDELETE() {
        let expectation = expectationWithDescription("testCancelDELETE")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.DELETE("/delete", completion: { JSON, error in
            let canceledCode = error?.code == -999
            XCTAssertTrue(canceledCode)

            expectation.fulfill()
        })

        networking.cancelDELETE("/delete")

        waitForExpectationsWithTimeout(3.0, handler: nil)
    }

    func testDELETEWithInvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.DELETE("/invalidpath", completion: { JSON, error in
            if let JSON: AnyObject = JSON {
                fatalError("JSON not nil: \(JSON)")
            } else {
                XCTAssertNotNil(error)
            }
        })
    }

    func testDELETEStubs() {
        let networking = Networking(baseURL: baseURL)

        networking.stubDELETE("/stories", response: ["name" : "Elvis"])

        networking.DELETE("/stories", completion: { JSON, error in
            let JSON = JSON as! [String : String]
            let value = JSON["name"]
            XCTAssertEqual(value!, "Elvis")
        })
    }

    func testDELETEStubsUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.stubDELETE("/entries", fileName: "entries.json", bundle: NSBundle(forClass: self.classForKeyedArchiver!))

        networking.DELETE("/entries", completion: { JSON, error in
            let JSON = JSON as! [[String : AnyObject]]
            let entry = JSON[0]
            let value = entry["title"] as! String
            XCTAssertEqual(value, "Entry 1")
        })
    }
}
