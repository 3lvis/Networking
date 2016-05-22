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
            guard let JSON = JSON as? [String : AnyObject] else { XCTFail(); return }
            let JSONResponse = JSON["json"] as? [String : String]
            XCTAssertEqual("jameson", JSONResponse?["username"])
            XCTAssertEqual("secret", JSONResponse?["password"])
            XCTAssertNil(error)
        }
    }

    func testPOSTWithNoParameters() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post") { JSON, error in
            let JSONResponse = JSON as? [String : AnyObject]
            XCTAssertEqual("http://httpbin.org/post", JSONResponse?["url"] as? String)
            XCTAssertNil(error)
        }
    }

    func testPOSTWithFormURLEncoded() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post", parameterType: .FormURLEncoded, parameters: ["custname" : "jameson"]) { JSON, error in
            guard let JSON = JSON as? [String : AnyObject] else { XCTFail(); return }
            let JSONResponse = JSON["form"] as? [String : String]
            XCTAssertEqual("jameson", JSONResponse?["custname"])
            XCTAssertNil(error)
        }
    }

    func testPOSTWithMultipartFormData() {
        let networking = Networking(baseURL: baseURL)

        let data = "SAMPLEDATA".dataUsingEncoding(NSUTF8StringEncoding)!
        let part = FormPart(data: data, parameterName: "pig", filename: "pig.png")
        networking.POST("/post", parameters: ["Hi": "Bye", "Hi2": "Bye2"], part: part) { JSON, error in
            let data = try! NSJSONSerialization.dataWithJSONObject(JSON!, options: .PrettyPrinted)
            let string = NSString(data: data, encoding: NSUTF8StringEncoding)!
            print(string)
            let JSONResponse = JSON as! [String : AnyObject]
            XCTAssertEqual("http://httpbin.org/post", JSONResponse["url"] as? String)
            XCTAssertNil(error)
        }
    }

    func testUploadingAnImageWithMultipartFormData() {
        guard let path = NSBundle(forClass: POSTTests.self).pathForResource("Keys", ofType: "plist") else { return }
        guard let dictionary = NSDictionary(contentsOfFile: path) else { return }
        guard let CloudinaryCloudName = dictionary["CloudinaryCloudName"] as? String where CloudinaryCloudName.characters.count > 0 else { return }
        guard let CloudinarySecret = dictionary["CloudinarySecret"] as? String where CloudinarySecret.characters.count > 0 else { return }
        guard let CloudinaryAPIKey = dictionary["CloudinaryAPIKey"] as? String where CloudinaryAPIKey.characters.count > 0 else { return }

        let networking = Networking(baseURL: "https://api.cloudinary.com")

        let pigImage = NetworkingImage.find(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self))
        let pigImageData = pigImage.PNGData()!
        let timestamp = "\(Int(NSDate().timeIntervalSince1970))"
        let part = FormPart(data: pigImageData, parameterName: "file", filename: "\(timestamp).png")
        var parameters = [
            "timestamp": timestamp,
            "public_id": timestamp
        ]
        let signature = SHA1.signatureUsingParameters(parameters, secret: CloudinarySecret)
        parameters["api_key"] = CloudinaryAPIKey
        parameters["signature"] = signature

        networking.POST("/v1_1/\(CloudinaryCloudName)/image/upload", parameters: parameters, part: part) { JSON, error in
            let JSONResponse = JSON as! [String : AnyObject]
            XCTAssertEqual(timestamp, JSONResponse["original_filename"] as? String)
            XCTAssertNil(error)

            self.deleteAllCloudinaryPhotos(networking: networking, cloudName: CloudinaryCloudName, secret: CloudinarySecret, APIKey: CloudinaryAPIKey)
        }
    }

    func testPOSTWithIvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/posdddddt", parameters: ["username" : "jameson", "password" : "secret"]) { JSON, error in
            XCTAssertEqual(error?.code, 404)
            XCTAssertNil(JSON)
        }
    }

    func testFakePOST() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/story", response: [["name" : "Elvis"]])

        networking.POST("/story", parameters: ["username" : "jameson", "password" : "secret"]) { JSON, error in
            let JSON = JSON as? [[String : String]]
            let value = JSON?[0]["name"]
            XCTAssertEqual(value, "Elvis")
        }
    }

    func testFakePOSTWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/story", response: nil, statusCode: 401)

        networking.POST("/story") { JSON, error in
            XCTAssertEqual(error?.code, 401)
        }
    }

    func testFakePOSTUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/entries", fileName: "entries.json", bundle: NSBundle(forClass: POSTTests.self))

        networking.POST("/entries") { JSON, error in
            guard let JSON = JSON as? [[String : AnyObject]] else { XCTFail(); return }
            let entry = JSON[0]
            let value = entry["title"] as? String
            XCTAssertEqual(value, "Entry 1")
        }
    }

    func testCancelPOST() {
        let expectation = expectationWithDescription("testCancelPOST")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.POST("/post", parameters: ["username" : "jameson", "password" : "secret"]) { JSON, error in
            XCTAssertEqual(error?.code, -999)
            expectation.fulfill()
        }

        networking.cancelPOST("/post")

        waitForExpectationsWithTimeout(15.0, handler: nil)
    }

    func deleteAllCloudinaryPhotos(networking networking: Networking, cloudName: String, secret: String, APIKey: String) {
        networking.authenticate(username: APIKey, password: secret)
        networking.DELETE("/v1_1/\(cloudName)/resources/image/upload?all=true") { JSON, error in }
    }
}