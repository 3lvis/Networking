import Foundation
import XCTest
@testable import Networking

class NewNetworkingTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testNewGET() async throws {
        let networking = Networking(baseURL: baseURL)

        let result: Result<Friend, NetworkingError> = await networking.newGet("/get")

        switch result {
        case .success(_):
            print("worked")
        case .failure(let failure):
            print(failure.localizedDescription)
        }
    }

    func testNewPOST() async throws {
        let networking = Networking(baseURL: baseURL)

        let result: Result<Void, NetworkingError> = await networking.newPost("/get", parameters: ["String": "String"])

        switch result {
        case .success(_):
            print("worked")
        case .failure(let failure):
            print(failure.localizedDescription)
        }
    }

    func testNetworkingJSON() async throws {
        let networking = Networking(baseURL: baseURL)

        let result: Result<NetworkingResponse, NetworkingError> = await networking.newGet("/auth")
        switch result {
        case .success(let success):
            _ = success.headers.string(for: "access-token")
            _ = success.body.string(for: "id")
        case .failure(let failure):
            print(failure.localizedDescription)
        }
    }

    func testErrorNetworkingJSON() async throws {
        let networking = Networking(baseURL: baseURL)

        let response: [String: Any] = [
            "errors": [
                "phone_number": ["has already been taken"]
            ]
        ]
        networking.fakePOST("/auth", response: response, statusCode: 422)

        let result: Result<NetworkingResponse, NetworkingError> = await networking.newPost("/auth", parameters: [:])
        switch result {
        case .success(_): break
        case .failure(let response):
            XCTAssertTrue(response.errorDescription!.contains("has already been taken"))
        }
    }
}
