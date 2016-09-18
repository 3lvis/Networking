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
        let parameters = [
            "string": "valueA",
            "int": 20,
            "double": 20.0,
            "bool": true,
        ] as [String: Any]
        networking.POST("/post", parameters: parameters) { JSON, error in
            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            guard let JSONResponse = JSON["json"] as? [String: Any] else { XCTFail(); return }
            XCTAssertEqual(JSONResponse["string"] as? String, "valueA")
            XCTAssertEqual(JSONResponse["int"] as? Int, 20)
            XCTAssertEqual(JSONResponse["double"] as? Double, 20.0)
            XCTAssertEqual(JSONResponse["bool"] as? Bool, true)
            XCTAssertNil(error)
        }
    }

    func testPOSTWithHeaders() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post") { JSON, headers, error in
            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            guard let url = JSON["url"] as? String else { XCTFail(); return }
            guard let contentType = headers["Content-Type"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "http://httpbin.org/post")
            XCTAssertEqual(contentType, "application/json")
        }
    }

    func testPOSTWithNoParameters() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post") { JSON, error in
            let JSONResponse = JSON as? [String: Any]
            XCTAssertEqual("http://httpbin.org/post", JSONResponse?["url"] as? String)
            XCTAssertNil(error)
        }
    }

    func testPOSTWithFormURLEncoded() {
        let networking = Networking(baseURL: baseURL)
        let parameters = [
            "string": "valueA",
            "int": 20,
            "double": 20.0,
            "bool": true,
        ] as [String: Any]
        networking.POST("/post", parameterType: .formURLEncoded, parameters: parameters) { JSON, error in
            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            guard let form = JSON["form"] as? [String: Any] else { XCTFail(); return }
            XCTAssertEqual(form["string"] as? String, "valueA")
            XCTAssertEqual(form["int"] as? String, "20")
            XCTAssertEqual(form["double"] as? String, "20.0")
            XCTAssertEqual(form["bool"] as? String, "true")
            XCTAssertNil(error)
        }
    }

    func testPOSTWithMultipartFormData() {
        let networking = Networking(baseURL: baseURL)

        let item1 = "FIRSTDATA"
        let item2 = "SECONDDATA"
        let part1 = FormDataPart(data: item1.data(using: .utf8)!, parameterName: item1, filename: "\(item1).png")
        let part2 = FormDataPart(data: item2.data(using: .utf8)!, parameterName: item2, filename: "\(item2).png")
        let parameters = [
            "string": "valueA",
            "int": 20,
            "double": 20.0,
            "bool": true,
        ] as [String: Any]
        networking.POST("/post", parameters: parameters as Any?, parts: [part1, part2]) { JSON, error in
            XCTAssertNil(error)

            guard let JSON = JSON as? [String: Any] else { XCTFail(); return }
            XCTAssertEqual(JSON["url"] as? String, "http://httpbin.org/post")

            guard let headers = JSON["headers"] as? [String: Any] else { XCTFail(); return }
            XCTAssertEqual(headers["Content-Type"] as? String, "multipart/form-data; boundary=\(networking.boundary)")

            guard let files = JSON["files"] as? [String: Any] else { XCTFail(); return }
            XCTAssertEqual(files[item1] as? String, item1)
            XCTAssertEqual(files[item2] as? String, item2)

            guard let form = JSON["form"] as? [String: Any] else { XCTFail(); return }
            XCTAssertEqual(form["string"] as? String, "valueA")
            XCTAssertEqual(form["int"] as? String, "20")
            XCTAssertEqual(form["double"] as? String, "20.0")
            XCTAssertEqual(form["bool"] as? String, "true")
        }
    }

    func testUploadingAnImageWithMultipartFormData() {
        guard let path = Bundle(for: POSTTests.self).path(forResource: "Keys", ofType: "plist") else { return }
        guard let dictionary = NSDictionary(contentsOfFile: path) else { return }
        guard let CloudinaryCloudName = dictionary["CloudinaryCloudName"] as? String, CloudinaryCloudName.characters.count > 0 else { return }
        guard let CloudinarySecret = dictionary["CloudinarySecret"] as? String, CloudinarySecret.characters.count > 0 else { return }
        guard let CloudinaryAPIKey = dictionary["CloudinaryAPIKey"] as? String, CloudinaryAPIKey.characters.count > 0 else { return }

        let networking = Networking(baseURL: "https://api.cloudinary.com")
        let timestamp = "\(Int(Date().timeIntervalSince1970))"

        let pngImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: ImageTests.self))
        let pngImageData = pngImage.pngData()!
        let pngPart = FormDataPart(data: pngImageData, parameterName: "file", filename: "\(timestamp).png")

        var parameters = [
            "timestamp": timestamp,
            "public_id": timestamp,
        ]
        let signature = SHA1.signature(usingParameters: parameters, secret: CloudinarySecret)
        parameters["api_key"] = CloudinaryAPIKey
        parameters["signature"] = signature

        networking.POST("/v1_1/\(CloudinaryCloudName)/image/upload", parameters: parameters as Any?, part: pngPart) { JSON, error in
            let JSONResponse = JSON as! [String: Any]
            XCTAssertEqual(timestamp, JSONResponse["original_filename"] as? String)
            XCTAssertNil(error)

            self.deleteAllCloudinaryPhotos(networking: networking, cloudName: CloudinaryCloudName, secret: CloudinarySecret, APIKey: CloudinaryAPIKey)
        }
    }

    func testPOSTWithIvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/posdddddt", parameters: ["username": "jameson", "password": "secret"]) { JSON, error in
            XCTAssertEqual(error?.code, 404)
            XCTAssertNil(JSON)
        }
    }

    func testFakePOST() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/story", response: [["name": "Elvis"]])

        networking.POST("/story", parameters: ["username": "jameson", "password": "secret"]) { JSON, error in
            let JSON = JSON as? [[String: String]]
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

        networking.fakePOST("/entries", fileName: "entries.json", bundle: Bundle(for: POSTTests.self))

        networking.POST("/entries") { JSON, error in
            guard let JSON = JSON as? [[String: Any]] else { XCTFail(); return }
            let entry = JSON[0]
            let value = entry["title"] as? String
            XCTAssertEqual(value, "Entry 1")
        }
    }

    func testCancelPOSTWithPath() {
        let expectation = self.expectation(description: "testCancelPOST")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        var completed = false
        networking.POST("/post", parameters: ["username": "jameson", "password": "secret"]) { JSON, error in
            XCTAssertTrue(completed)
            XCTAssertEqual(error?.code, -999)
            expectation.fulfill()
        }

        networking.cancelPOST("/post") {
            completed = true
        }

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelPOSTWithID() {
        let expectation = self.expectation(description: "testCancelPOST")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        var completed = false
        let requestID = networking.POST("/post", parameters: ["username": "jameson", "password": "secret"]) { JSON, error in
            XCTAssertTrue(completed)
            XCTAssertEqual(error?.code, -999)
            expectation.fulfill()
        }

        networking.cancel(with: requestID) {
            completed = true
        }

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func deleteAllCloudinaryPhotos(networking: Networking, cloudName: String, secret: String, APIKey: String) {
        networking.authenticate(username: APIKey, password: secret)
        networking.DELETE("/v1_1/\(cloudName)/resources/image/upload?all=true") { JSON, error in }
    }
}
