import Foundation
import XCTest

class POSTTests: XCTestCase {
    let baseURL = "http://httpbin.org"

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
        networking.POST("/post", parameters: ["username" : "jameson", "password" : "secret"]) { JSON, error in
            let JSONResponse = (JSON as! [String : AnyObject])["json"] as! [String : String]
            XCTAssertEqual("jameson", JSONResponse["username"])
            XCTAssertEqual("secret", JSONResponse["password"])
            XCTAssertNil(error)
        }
    }

    func testPOSTWithNoParameters() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post") { JSON, error in
            let JSONResponse = JSON as! [String : AnyObject]
            XCTAssertEqual("http://httpbin.org/post", JSONResponse["url"] as? String)
            XCTAssertNil(error)
        }
    }

    func testPOSTWithFormURLEncoded() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post", parameterType: .FormURLEncoded, parameters: ["custname" : "jameson"]) { JSON, error in
            let JSONResponse = (JSON as! [String : AnyObject])["form"] as! [String : String]
            XCTAssertEqual("jameson", JSONResponse["custname"])
            XCTAssertNil(error)
        }
    }

    func testPOSTWithIvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/posdddddt", parameters: ["username" : "jameson", "password" : "secret"]) { JSON, error in
            XCTAssertEqual(error!.code, 404)
            XCTAssertNil(JSON)
        }
    }

    func testFakePOST() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/story", response: [["name" : "Elvis"]])

        networking.POST("/story", parameters: ["username" : "jameson", "password" : "secret"]) { JSON, error in
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

        networking.fakePOST("/entries", fileName: "entries.json", bundle: NSBundle(forClass: self.classForKeyedArchiver!))

        networking.POST("/entries") { JSON, error in
            let JSON = JSON as! [[String : AnyObject]]
            let entry = JSON[0]
            let value = entry["title"] as! String
            XCTAssertEqual(value, "Entry 1")
        }
    }

    func testCancelPOST() {
        let expectation = expectationWithDescription("testCancelPOST")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.POST("/post", parameters: ["username" : "jameson", "password" : "secret"]) { JSON, error in
            let canceledCode = error!.code == -999
            XCTAssertTrue(canceledCode)

            expectation.fulfill()
        }

        networking.cancelPOST("/post")

        waitForExpectationsWithTimeout(15.0, handler: nil)
    }
}