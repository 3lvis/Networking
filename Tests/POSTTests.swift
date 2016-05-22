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

    func testPOSTWithFormData() {
        let networking = Networking(baseURL: baseURL)

        let data = "SAMPLEDATA".dataUsingEncoding(NSUTF8StringEncoding)!
        let part = FormPart(data: data, parameterName: "pig", filename: "pig.png", type: .PNG)
        networking.POST("/post", part: part, parameters: ["Hi": "Bye", "Hi2": "Bye2"]) { JSON, error in
            let data = try! NSJSONSerialization.dataWithJSONObject(JSON!, options: .PrettyPrinted)
            let string = NSString(data: data, encoding: NSUTF8StringEncoding)!
            print(string)
            let JSONResponse = JSON as! [String : AnyObject]
            XCTAssertEqual("http://httpbin.org/post", JSONResponse["url"] as? String)
            XCTAssertNil(error)
        }
    }

    /*
    func testUploadingAnImageWithFormData() {
        let networking = Networking(baseURL: "https://api.cloudinary.com")

        let pigImage = NetworkingImage.find(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self))
        let pigImageData = pigImage.PNGData()!
        let timestamp = "\(Int(NSDate().timeIntervalSince1970))"
        let part = FormPart(data: pigImageData, parameterName: "file", filename: "\(timestamp).png", type: .Data)
        var parameters = [
            "timestamp": timestamp,
            "public_id": timestamp
        ]
        let secret = "PROVIDE_YOUR_OWN"
        let APIKey = "PROVIDE_YOUR_OWN"
        let signature = SHA1.signatureUsingParameters(parameters, secret: secret)
        parameters["api_key"] = APIKey
        parameters["signature"] = signature

        networking.POST("/v1_1/elvisnunez/image/upload", part: part, parameters: parameters) { JSON, error in
            let JSONResponse = JSON as! [String : AnyObject]
            XCTAssertEqual(timestamp, JSONResponse["original_filename"] as? String)
            XCTAssertNil(error)
        }
    }
     */

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