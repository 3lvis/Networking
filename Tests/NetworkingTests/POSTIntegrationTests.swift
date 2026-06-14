import Foundation
import XCTest
@testable import Networking

class POSTIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testPOSTWithoutBody() async throws {
        let networking = Networking(baseURL: baseURL)
        // A bodyless POST carries no Content-Type — it just has to reach the endpoint and succeed.
        let result: Result<JSONResponse, NetworkingError> = await networking.post("/post")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/post")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testPOSTWithTypedBody() async throws {
        let networking = Networking(baseURL: baseURL)
        struct Payload: Encodable {
            let string: String
            let int: Int
            let double: Double
            let bool: Bool
        }
        // Distinct values so an Int/Double/Bool encoding mix-up would actually fail the assertions.
        let result: Result<PostJSONEcho, NetworkingError> = await networking.post("/post", body: Payload(string: "valueA", int: 20, double: 20.5, bool: false))
        switch result {
        case let .success(response):
            XCTAssertEqual(response.json.string, "valueA")
            XCTAssertEqual(response.json.int, 20)
            XCTAssertEqual(response.json.double, 20.5)
            XCTAssertEqual(response.json.bool, false)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testPOSTWithHeaders() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.post("/post")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/post")
            XCTAssertTrue(response.headers.string(for: "Content-Type")?.hasPrefix("application/json") ?? false)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testPOSTWithNoParameters() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.post("/post")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/post")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testPOSTWithFormURLEncoded() async throws {
        let networking = Networking(baseURL: baseURL)
        let parameters = [
            "string": "B&B",
            "int": "20",
            "double": "20.0",
            "bool": "true",
            "date": "2016-11-02T13:55:28+01:00",
        ]
        let result: Result<JSONResponse, NetworkingError> = await networking.post("/post", form: parameters)
        switch result {
        case let .success(response):
            let form = httpbinEchoedMap(response, "form")
            XCTAssertEqual(form["string"], "B&B")
            XCTAssertEqual(form["int"], "20")
            XCTAssertEqual(form["double"], "20.0")
            XCTAssertEqual(form["bool"], "true")
            XCTAssertEqual(form["date"], "2016-11-02T13:55:28+01:00")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testPOSTWithMultipartFormData() async throws {
        let networking = Networking(baseURL: baseURL)

        let item1 = "FIRSTDATA"
        let item2 = "SECONDDATA"
        let part1 = FormDataPart(data: item1.data(using: .utf8)!, parameterName: item1, filename: "\(item1).png")
        let part2 = FormDataPart(data: item2.data(using: .utf8)!, parameterName: item2, filename: "\(item2).png")
        let fields = [
            "string": "valueA",
            "int": "20",
            "double": "20.0",
            "bool": "true",
        ]
        let result: Result<JSONResponse, NetworkingError> = await networking.post("/post", parts: [part1, part2], fields: fields)
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/post")

            let headers = httpbinEchoedMap(response, "headers")
            XCTAssertEqual(headers["Content-Type"], "multipart/form-data; boundary=\(networking.boundary)")

            let files = httpbinEchoedMap(response, "files")
            XCTAssertEqual(files[item1], item1)
            XCTAssertEqual(files[item2], item2)

            let form = httpbinEchoedMap(response, "form")
            XCTAssertEqual(form["string"], "valueA")
            XCTAssertEqual(form["int"], "20")
            XCTAssertEqual(form["double"], "20.0")
            XCTAssertEqual(form["bool"], "true")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testPOSTWithMultipartFormDataNoParameters() async throws {
        let networking = Networking(baseURL: baseURL)

        let item1 = "FIRSTDATA"
        let part1 = FormDataPart(data: item1.data(using: .utf8)!, parameterName: item1, filename: "\(item1).png")
        let result: Result<JSONResponse, NetworkingError> = await networking.post("/post", parts: [part1])
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/post")

            let headers = httpbinEchoedMap(response, "headers")
            XCTAssertEqual(headers["Content-Type"], "multipart/form-data; boundary=\(networking.boundary)")

            let files = httpbinEchoedMap(response, "files")
            XCTAssertEqual(files[item1], item1)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testUploadingAnImageWithMultipartFormData() async throws {
        let networking = Networking(baseURL: baseURL)

        let imageURL = try XCTUnwrap(Bundle.module.url(forResource: "pig", withExtension: "png"))
        let imageData = try Data(contentsOf: imageURL)
        let imagePart = FormDataPart(data: imageData, parameterName: "file", filename: "pig.png")

        let result: Result<JSONResponse, NetworkingError> = await networking.post("/post", parts: [imagePart], fields: ["public_id": "pig"])
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "url"), "\(TestConfig.httpbinBaseURL)/post")

            let headers = httpbinEchoedMap(response, "headers")
            XCTAssertEqual(headers["Content-Type"], "multipart/form-data; boundary=\(networking.boundary)")

            // The image arrived as a multipart file part. httpbin echoes file content as a
            // (lossy) JSON string, so assert the PNG signature crossed the wire rather than
            // byte-equality.
            let files = httpbinEchoedMap(response, "files")
            XCTAssertTrue(files["file"]?.contains("PNG") ?? false)

            let form = httpbinEchoedMap(response, "form")
            XCTAssertEqual(form["public_id"], "pig")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testPOSTWithEmptyResponseBody() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.post("/status/204")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.statusCode, 204)
            XCTAssertTrue(response.body.isEmpty)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testPOSTWithIvalidPath() async throws {
        let networking = Networking(baseURL: baseURL)
        let result: Result<JSONResponse, NetworkingError> = await networking.post("/posdddddt", body: ["username": "jameson", "password": "secret"])
        switch result {
        case .success:
            XCTFail()
        case let .failure(error):
            guard case let .clientError(statusCode, _) = error else {
                return XCTFail("expected a client error, got \(error)")
            }
            XCTAssertEqual(statusCode, 404)
        }
    }
}

// httpbin echoes a posted JSON body back under the top-level `json` key.
private struct PostJSONEcho: Decodable {
    struct Payload: Decodable {
        let string: String
        let int: Int
        let double: Double
        let bool: Bool
    }
    let json: Payload
}
