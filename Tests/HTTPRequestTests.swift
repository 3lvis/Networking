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
        networking.GET("/get") { JSON, error in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testGET() {
        let networking = Networking(baseURL: baseURL)
        networking.GET("/get") { JSON, error in
            let JSON = JSON as! [String : AnyObject]
            let url = JSON["url"] as! String
            XCTAssertEqual(url, "http://httpbin.org/get")
        }
    }

    func testGETWithInvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.GET("/invalidpath") { JSON, error in
            XCTAssertNil(JSON)
            XCTAssertNotNil(error)
        }
    }

    func testFakeGET() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/stories", response: ["name" : "Elvis"])

        networking.GET("/stories") { JSON, error in
            let JSON = JSON as! [String : String]
            let value = JSON["name"]
            XCTAssertEqual(value!, "Elvis")
        }
    }

    func testFakeGETWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/stories", response: nil, statusCode: 401)

        networking.GET("/stories") { JSON, error in
            XCTAssertEqual(401, error!.code)
        }
    }

    func testFakeGETUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/entries", fileName: "entries.json", bundle: Bundle(for: self.classForKeyedArchiver!))

        networking.GET("/entries") { JSON, error in
            let JSON = JSON as! [[String : AnyObject]]
            let entry = JSON[0]
            let value = entry["title"] as! String
            XCTAssertEqual(value, "Entry 1")
        }
    }

    func testCancelGET() {
        let expectation = self.expectation(withDescription: "testCancelGET")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.GET("/get") { JSON, error in
            let canceledCode = error?.code == -999
            XCTAssertTrue(canceledCode)

            expectation.fulfill()
        }

        networking.cancelGET("/get")

        waitForExpectations(withTimeout: 15.0, handler: nil)
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
            let connectionError = NSError(domain: Networking.ErrorDomain, code: statusCode, userInfo: [NSLocalizedDescriptionKey : HTTPURLResponse.localizedString(forStatusCode: statusCode)])
            XCTAssertEqual(error, connectionError)
        }

        statusCode = 400
        networking.GET("/status/\(statusCode)") { JSON, error in
            XCTAssertNil(JSON)
            let connectionError = NSError(domain: Networking.ErrorDomain, code: statusCode, userInfo: [NSLocalizedDescriptionKey : HTTPURLResponse.localizedString(forStatusCode: statusCode)])
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
        networking.POST("/post", parameters: ["username":"jameson", "password":"secret"]) { JSON, error in
            let JSONResponse = (JSON as! [String : AnyObject])["json"] as! [String : String]
            XCTAssertEqual("jameson", JSONResponse["username"])
            XCTAssertEqual("secret", JSONResponse["password"])
            XCTAssertNotNil(JSON!, "JSON not nil")
            XCTAssertNil(error, "Error")
        }
    }

    func testPOSTWithNoParameters() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post") { JSON, error in
            let JSONResponse = JSON as! [String : AnyObject]
            XCTAssertEqual("http://httpbin.org/post", JSONResponse["url"] as? String)
            XCTAssertNotNil(JSON!, "JSON not nil")
            XCTAssertNil(error, "Error")
        }
    }

    func testPOSTWithFormURLEncoded() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post", contentType: .formURLEncoded, parameters: ["custname":"jameson"]) { JSON, error in
            let JSONResponse = (JSON as! [String : AnyObject])["form"] as! [String : String]
            XCTAssertEqual("jameson", JSONResponse["custname"])
            XCTAssertNotNil(JSON!, "JSON not nil")
            XCTAssertNil(error, "Error")
        }
    }

    func testPOSTWithIvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/posdddddt", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            XCTAssertNotNil(error)
            XCTAssertNil(JSON)
        }
    }

    func testFakePOST() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/story", response: [["name" : "Elvis"]])

        networking.POST("/story", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            let JSON = JSON as! [[String : String]]
            let value = JSON[0]["name"]
            XCTAssertEqual(value!, "Elvis")
        }
    }

    func testFakePOSTWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/story", response: nil, statusCode: 401)

        networking.POST("/story") { JSON, error in
            XCTAssertEqual(401, error!.code)
        }
    }

    func testFakePOSTUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/entries", fileName: "entries.json", bundle: Bundle(for: self.classForKeyedArchiver!))

        networking.POST("/entries") { JSON, error in
            let JSON = JSON as! [[String : AnyObject]]
            let entry = JSON[0]
            let value = entry["title"] as! String
            XCTAssertEqual(value, "Entry 1")
        }
    }

    func testCancelPOST() {
        let expectation = self.expectation(withDescription: "testCancelPOST")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.POST("/post", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            let canceledCode = error?.code == -999
            XCTAssertTrue(canceledCode)

            expectation.fulfill()
        }

        networking.cancelPOST("/post")

        waitForExpectations(withTimeout: 15.0, handler: nil)
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

    func testPUTWithIvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.PUT("/posdddddt", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            XCTAssertNotNil(error)
            XCTAssertNil(JSON)
        }
    }

    func testFakePUT() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/story", response: [["name" : "Elvis"]])

        networking.PUT("/story", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            let JSON = JSON as! [[String : String]]
            let value = JSON[0]["name"]
            XCTAssertEqual(value!, "Elvis")
        }
    }

    func testFakePUTWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/story", response: nil, statusCode: 401)

        networking.PUT("/story", parameters: nil) { JSON, error in
            XCTAssertEqual(401, error!.code)
        }
    }

    func testFakePUTUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/entries", fileName: "entries.json", bundle: Bundle(for: self.classForKeyedArchiver!))

        networking.PUT("/entries", parameters: nil) { JSON, error in
            let JSON = JSON as! [[String : AnyObject]]
            let entry = JSON[0]
            let value = entry["title"] as! String
            XCTAssertEqual(value, "Entry 1")
        }
    }

    func testCancelPUT() {
        let expectation = self.expectation(withDescription: "testCancelPUT")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.PUT("/put", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            let canceledCode = error?.code == -999
            XCTAssertTrue(canceledCode)

            expectation.fulfill()
        }

        networking.cancelPUT("/put")

        waitForExpectations(withTimeout: 15.0, handler: nil)
    }
}

// MARK: DELETE

extension HTTPRequestTests {
    func testSynchronousDELETE() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.DELETE("/delete") { JSON, error in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testDELETE() {
        let networking = Networking(baseURL: baseURL)
        networking.DELETE("/delete") { JSON, error in
            let JSON = JSON as! [String : AnyObject]
            let url = JSON["url"] as! String
            XCTAssertEqual(url, "http://httpbin.org/delete")
        }
    }

    func testDELETEWithInvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.DELETE("/invalidpath") { JSON, error in
            XCTAssertNil(JSON)
            XCTAssertNotNil(error)
        }
    }

    func testFakeDELETE() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/stories", response: ["name" : "Elvis"])

        networking.DELETE("/stories") { JSON, error in
            let JSON = JSON as! [String : String]
            let value = JSON["name"]
            XCTAssertEqual(value!, "Elvis")
        }
    }

    func testFakeDELETEWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/story", response: nil, statusCode: 401)

        networking.DELETE("/story") { JSON, error in
            XCTAssertEqual(401, error!.code)
        }
    }

    func testFakeDELETEUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/entries", fileName: "entries.json", bundle: Bundle(for: self.classForKeyedArchiver!))

        networking.DELETE("/entries") { JSON, error in
            let JSON = JSON as! [[String : AnyObject]]
            let entry = JSON[0]
            let value = entry["title"] as! String
            XCTAssertEqual(value, "Entry 1")
        }
    }

    func testCancelDELETE() {
        let expectation = self.expectation(withDescription: "testCancelDELETE")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.DELETE("/delete") { JSON, error in
            let canceledCode = error?.code == -999
            XCTAssertTrue(canceledCode)

            expectation.fulfill()
        }

        networking.cancelDELETE("/delete")

        waitForExpectations(withTimeout: 15.0, handler: nil)
    }
}
