import Foundation
import XCTest
@testable import Networking

class POSTIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testPOSTWithoutParameters() async throws {
        let networking = Networking(baseURL: baseURL)
        let result = try await networking.oldPost("/post", parameters: nil)
        switch result {
        case let .success(response):
            let json = response.dictionaryBody

            let headers = httpbinEchoedMap(json, "headers")
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

            let headers = httpbinEchoedMap(json, "headers")
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
            XCTAssertEqual(url, "\(TestConfig.httpbinBaseURL)/post")

            let headers = response.headers
            XCTAssertTrue((headers["Content-Type"] as? String)?.hasPrefix("application/json") ?? false)
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
            XCTAssertEqual("\(TestConfig.httpbinBaseURL)/post", JSONResponse["url"] as? String)
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
            let form = httpbinEchoedMap(json, "form")
            XCTAssertEqual(form["string"], "B&B")
            XCTAssertEqual(form["int"], "20")
            XCTAssertEqual(form["double"], "20.0")
            XCTAssertEqual(form["bool"], "true")
            XCTAssertEqual(form["date"], "2016-11-02T13:55:28+01:00")
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
            XCTAssertEqual(json["url"] as? String, "\(TestConfig.httpbinBaseURL)/post")

            let headers = httpbinEchoedMap(json, "headers")
            XCTAssertEqual(headers["Content-Type"], "multipart/form-data; boundary=\(networking.boundary)")

            let files = httpbinEchoedMap(json, "files")
            XCTAssertEqual(files[item1], item1)
            XCTAssertEqual(files[item2], item2)

            let form = httpbinEchoedMap(json, "form")
            XCTAssertEqual(form["string"], "valueA")
            XCTAssertEqual(form["int"], "20")
            XCTAssertEqual(form["double"], "20.0")
            XCTAssertEqual(form["bool"], "true")
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
            XCTAssertEqual(json["url"] as? String, "\(TestConfig.httpbinBaseURL)/post")

            let headers = httpbinEchoedMap(json, "headers")
            XCTAssertEqual(headers["Content-Type"], "multipart/form-data; boundary=\(networking.boundary)")

            let files = httpbinEchoedMap(json, "files")
            XCTAssertEqual(files[item1], item1)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testUploadingAnImageWithMultipartFormData() async throws {
        let networking = Networking(baseURL: baseURL)

        let imageURL = try XCTUnwrap(Bundle.module.url(forResource: "pig", withExtension: "png"))
        let imageData = try Data(contentsOf: imageURL)
        let imagePart = FormDataPart(data: imageData, parameterName: "file", filename: "pig.png")

        let result = try await networking.oldPost("/post", parameters: ["public_id": "pig"], parts: [imagePart])
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json["url"] as? String, "\(TestConfig.httpbinBaseURL)/post")

            let headers = httpbinEchoedMap(json, "headers")
            XCTAssertEqual(headers["Content-Type"], "multipart/form-data; boundary=\(networking.boundary)")

            // The image arrived as a multipart file part. httpbin echoes file content as a
            // (lossy) JSON string, so assert the PNG signature crossed the wire rather than
            // byte-equality.
            let files = httpbinEchoedMap(json, "files")
            XCTAssertTrue(files["file"]?.contains("PNG") ?? false)

            let form = httpbinEchoedMap(json, "form")
            XCTAssertEqual(form["public_id"], "pig")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

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


    func deleteAllCloudinaryPhotos(networking: Networking, cloudName: String, secret: String, APIKey: String) async throws {
        networking.setAuthorizationHeader(username: APIKey, password: secret)
        _ = try await networking.oldDelete("/v1_1/\(cloudName)/resources/image/upload?all=true")
    }
}
