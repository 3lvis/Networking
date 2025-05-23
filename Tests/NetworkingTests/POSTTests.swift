import Foundation
import XCTest
@testable import Networking

class POSTTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testPOSTWithoutParameters() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldPost("/post", parameters: nil)
        switch result {
        case let .success(response):
            let json = response.dictionaryBody

            guard let headers = json["headers"] as? [String: String] else { XCTFail(); return }
            XCTAssertEqual(headers["Content-Type"], "application/json")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testPOSTWithParameters() async throws {
        let networking = Networking(baseURL: baseURL)
        let parameters = [
            "string": "valueA",
            "int": 20,
            "double": 20.0,
            "bool": true,
        ] as [String: Any]
        let result = try await networking.oldPost("/post", parameters: parameters)
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            guard let JSONResponse = json["json"] as? [String: Any] else { XCTFail(); return }
            XCTAssertEqual(JSONResponse["string"] as? String, "valueA")
            XCTAssertEqual(JSONResponse["int"] as? Int, 20)
            XCTAssertEqual(JSONResponse["double"] as? Double, 20.0)
            XCTAssertEqual(JSONResponse["bool"] as? Bool, true)

            guard let headers = json["headers"] as? [String: String] else { XCTFail(); return }
            let contentType = headers["Content-Type"]
            XCTAssertEqual(contentType, "application/json")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testPOSTWithHeaders() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldPost("/post")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            guard let url = json["url"] as? String else { XCTFail(); return }
            XCTAssertEqual(url, "http://httpbin.org/post")

            let headers = response.headers
            guard let connection = headers["Connection"] as? String else { XCTFail(); return }
            XCTAssertEqual(connection, "keep-alive")
            XCTAssertEqual(headers["Content-Type"] as? String, "application/json")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testPOSTWithNoParameters() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldPost("/post")
        switch result {
        case let .success(response):
            let JSONResponse = response.dictionaryBody
            XCTAssertEqual("http://httpbin.org/post", JSONResponse["url"] as? String)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testPOSTWithFormURLEncoded() async throws {
        let networking = Networking(baseURL: baseURL)
        let parameters = [
            "string": "B&B",
            "int": 20,
            "double": 20.0,
            "bool": true,
            "date": "2016-11-02T13:55:28+01:00",
        ] as [String: Any]
        let result = try await networking.oldPost("/post", parameterType: .formURLEncoded, parameters: parameters)
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            guard let form = json["form"] as? [String: Any] else { XCTFail(); return }
            XCTAssertEqual(form["string"] as? String, "B&B")
            XCTAssertEqual(form["int"] as? String, "20")
            XCTAssertEqual(form["double"] as? String, "20.0")
            XCTAssertEqual(form["bool"] as? String, "true")
            XCTAssertEqual(form["date"] as? String, "2016-11-02T13:55:28+01:00")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testPOSTWithMultipartFormData() async throws {
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
        let result = try await networking.oldPost("/post", parameters: parameters, parts: [part1, part2])
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
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
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testPOSTWithMultipartFormDataNoParameters() async throws {
        let networking = Networking(baseURL: baseURL)

        let item1 = "FIRSTDATA"
        let part1 = FormDataPart(data: item1.data(using: .utf8)!, parameterName: item1, filename: "\(item1).png")
        let result = try await networking.oldPost("/post", parameters: nil, parts: [part1])
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["url"] as? String, "http://httpbin.org/post")

            guard let headers = json["headers"] as? [String: Any] else { XCTFail(); return }
            XCTAssertEqual(headers["Content-Type"] as? String, "multipart/form-data; boundary=\(networking.boundary)")

            guard let files = json["files"] as? [String: Any] else { XCTFail(); return }
            XCTAssertEqual(files[item1] as? String, item1)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    /*
    func testUploadingAnImageWithMultipartFormData() {
        guard let path = .module.path(forResource: "Keys", ofType: "plist") else { return }
        guard let dictionary = NSDictionary(contentsOfFile: path) else { return }
        guard let CloudinaryCloudName = dictionary["CloudinaryCloudName"] as? String, CloudinaryCloudName.count > 0 else { return }
        guard let CloudinarySecret = dictionary["CloudinarySecret"] as? String, CloudinarySecret.count > 0 else { return }
        guard let CloudinaryAPIKey = dictionary["CloudinaryAPIKey"] as? String, CloudinaryAPIKey.count > 0 else { return }

        let networking = Networking(baseURL: "https://api.cloudinary.com")
        let timestamp = "\(Int(Date().timeIntervalSince1970))"

        let pngImage = Image.find(named: "pig.png", inBundle: .module)
        let pngImageData = pngImage.pngData()!
        let pngPart = FormDataPart(data: pngImageData, parameterName: "file", filename: "\(timestamp).png")

        var parameters = [
            "timestamp": timestamp,
            "public_id": timestamp,
        ]
        let signature = SHA1.signature(usingParameters: parameters, secret: CloudinarySecret)
        parameters["api_key"] = CloudinaryAPIKey
        parameters["signature"] = signature

        networking.oldPost("/v1_1/\(CloudinaryCloudName)/image/upload", parameters: parameters, parts: [pngPart]) { result in
            switch result {
            case let .success(response):
                let JSONResponse = response.dictionaryBody
                XCTAssertEqual(timestamp, JSONResponse["original_filename"] as? String)

                self.deleteAllCloudinaryPhotos(networking: networking, cloudName: CloudinaryCloudName, secret: CloudinarySecret, APIKey: CloudinaryAPIKey)
            case let .failure(response):
                XCTFail(response.error.localizedDescription)
            }
        }
    }
    */

    func testPOSTWithIvalidPath() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldPost("/posdddddt", parameters: ["username": "jameson", "password": "secret"])
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertEqual(response.error.code, 404)
        }

    }

    // Disabling because I haven't found a way to test cancel
    /*
    func testCancelPOSTWithPath() {
        let expectation = self.expectation(description: "testCancelPOST")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        var completed = false
        networking.oldPost("/post", parameters: ["username": "jameson", "password": "secret"]) { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                XCTAssertTrue(completed)
                XCTAssertEqual(response.error.code, URLError.cancelled.rawValue)
                expectation.fulfill()
            }
        }

        networking.cancelPOST("/post")
        completed = true

        waitForExpectations(timeout: 15.0, handler: nil)
    }*/

    func deleteAllCloudinaryPhotos(networking: Networking, cloudName: String, secret: String, APIKey: String) async throws {
        networking.setAuthorizationHeader(username: APIKey, password: secret)
        _ = try await networking.oldDelete("/v1_1/\(cloudName)/resources/image/upload?all=true")
    }
}
