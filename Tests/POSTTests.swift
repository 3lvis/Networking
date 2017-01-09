import Foundation
import XCTest

class POSTTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testSynchronousPOST() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post", parameters: nil) { json, error in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testPOSTWithoutParameters() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post", parameters: nil) { json, error in
            print(String(data: try! JSONSerialization.data(withJSONObject: json!, options: .prettyPrinted), encoding: .utf8)!)
            guard let json = json as? [String: Any] else { XCTFail(); return }
            XCTAssertNil(error)

            guard let headers = json["headers"] as? [String: String] else { XCTFail(); return }
            XCTAssertEqual(headers["Content-Type"], "application/json")
        }
    }

    func testPOSTWithParameters() {
        let networking = Networking(baseURL: baseURL)
        let parameters = [
            "string": "valueA",
            "int": 20,
            "double": 20.0,
            "bool": true,
        ] as [String: Any]
        networking.POST("/post", parameters: parameters) { json, error in
            guard let json = json as? [String: Any] else { XCTFail(); return }
            guard let JSONResponse = json["json"] as? [String: Any] else { XCTFail(); return }
            XCTAssertEqual(JSONResponse["string"] as? String, "valueA")
            XCTAssertEqual(JSONResponse["int"] as? Int, 20)
            XCTAssertEqual(JSONResponse["double"] as? Double, 20.0)
            XCTAssertEqual(JSONResponse["bool"] as? Bool, true)
            XCTAssertNil(error)

            guard let headers = json["headers"] as? [String: String] else { XCTFail(); return }
            let contentType = headers["Content-Type"]
            XCTAssertEqual(contentType, "application/json")
        }
    }

    func testPOSTWithHeaders() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post") { json, headers, error in
            guard let json = json as? [String: Any] else { XCTFail(); return }
            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "http://httpbin.org/post")

            guard let connection = headers["Connection"] as? String else { XCTFail(); return }
            XCTAssertEqual(connection, "keep-alive")
            XCTAssertEqual(headers["Content-Type"] as? String, "application/json")
        }
    }

    func testPOSTWithNoParameters() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post") { json, error in
            let JSONResponse = json as? [String: Any]
            XCTAssertEqual("http://httpbin.org/post", JSONResponse?["url"] as? String)
            XCTAssertNil(error)
        }
    }

    func testPOSTWithFormURLEncoded() {
        let networking = Networking(baseURL: baseURL)
        let parameters = [
            "string": "B&B",
            "int": 20,
            "double": 20.0,
            "bool": true,
            "date": "2016-11-02T13:55:28+01:00",
        ] as [String: Any]
        networking.POST("/post", parameterType: .formURLEncoded, parameters: parameters) { json, error in
            guard let json = json as? [String: Any] else { XCTFail(); return }
            guard let form = json["form"] as? [String: Any] else { XCTFail(); return }
            XCTAssertEqual(form["string"] as? String, "B&B")
            XCTAssertEqual(form["int"] as? String, "20")
            XCTAssertEqual(form["double"] as? String, "20.0")
            XCTAssertEqual(form["bool"] as? String, "true")
            XCTAssertEqual(form["date"] as? String, "2016-11-02T13:55:28+01:00")
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
        networking.POST("/post", parameters: parameters as Any?, parts: [part1, part2]) { json, error in
            XCTAssertNil(error)

            guard let json = json as? [String: Any] else { XCTFail(); return }
            XCTAssertEqual(json["url"] as? String, "http://httpbin.org/post")

            guard let headers = json["headers"] as? [String: Any] else { XCTFail(); return }
            XCTAssertEqual(headers["Content-Type"] as? String, "multipart/form-data; boundary=\(networking.boundary)")

            guard let files = json["files"] as? [String: Any] else { XCTFail(); return }
            XCTAssertEqual(files[item1] as? String, item1)
            XCTAssertEqual(files[item2] as? String, item2)

            guard let form = json["form"] as? [String: Any] else { XCTFail(); return }
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

        networking.POST("/v1_1/\(CloudinaryCloudName)/image/upload", parameters: parameters as Any?, part: pngPart) { json, error in
            let JSONResponse = json as! [String: Any]
            XCTAssertEqual(timestamp, JSONResponse["original_filename"] as? String)
            XCTAssertNil(error)

            self.deleteAllCloudinaryPhotos(networking: networking, cloudName: CloudinaryCloudName, secret: CloudinarySecret, APIKey: CloudinaryAPIKey)
        }
    }

    func testPOSTWithIvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/posdddddt", parameters: ["username": "jameson", "password": "secret"]) { json, error in
            XCTAssertEqual(error?.code, 404)
            XCTAssertNil(json)
        }
    }

    func testFakePOST() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/story", response: [["name": "Elvis"]])

        networking.POST("/story", parameters: ["username": "jameson", "password": "secret"]) { json, error in
            let json = json as? [[String: String]]
            let value = json?[0]["name"]
            XCTAssertEqual(value, "Elvis")
        }
    }

    func testFakePOSTWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/story", response: nil, statusCode: 401)

        networking.POST("/story") { json, error in
            XCTAssertEqual(error?.code, 401)
        }
    }

    func testFakePOSTUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/entries", fileName: "entries.json", bundle: Bundle(for: POSTTests.self))

        networking.POST("/entries") { json, error in
            guard let json = json as? [[String: Any]] else { XCTFail(); return }
            let entry = json[0]
            let value = entry["title"] as? String
            XCTAssertEqual(value, "Entry 1")
        }
    }

    func testCancelPOSTWithPath() {
        let expectation = self.expectation(description: "testCancelPOST")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        var completed = false
        networking.POST("/post", parameters: ["username": "jameson", "password": "secret"]) { json, error in
            XCTAssertTrue(completed)
            XCTAssertEqual(error?.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }

        networking.cancelPOST("/post")
        completed = true

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelPOSTWithID() {
        let expectation = self.expectation(description: "testCancelPOST")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        var completed = false
        let requestID = networking.POST("/post", parameters: ["username": "jameson", "password": "secret"]) { json, error in
            XCTAssertTrue(completed)
            XCTAssertEqual(error?.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }

        networking.cancel(with: requestID) {
            completed = true
        }

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func deleteAllCloudinaryPhotos(networking: Networking, cloudName: String, secret: String, APIKey: String) {
        networking.setAuthorizationHeader(username: APIKey, password: secret)
        networking.DELETE("/v1_1/\(cloudName)/resources/image/upload?all=true") { json, error in }
    }
}
