import Foundation
import XCTest
import CoreLocation
@testable import Networking

class NewNetworkingTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testNewGET() async throws {
        let networking = Networking(baseURL: baseURL)

        let result: Result<Friend, NetworkingError> = await networking.get("/get")

        switch result {
        case .success(_):
            print("worked")
        case .failure(let failure):
            print(failure.localizedDescription)
        }
    }

    func testNewGETWithParams() async throws {
        let networking = Networking(baseURL: baseURL)

        let pickupCoordinate = CLLocationCoordinate2D(latitude: 59.91700978556453, longitude: 10.760668740407757)
        let deliveryCoordinate = CLLocationCoordinate2D(latitude: 59.937611066825674, longitude: 10.735343079276985)

        let parameters = [
            "pickup_latitude": pickupCoordinate.latitude,
            "pickup_longitude": pickupCoordinate.longitude,
            "delivery_latitude": deliveryCoordinate.latitude,
            "delivery_longitude": deliveryCoordinate.longitude
        ]

        let result: Result<Friend, NetworkingError> = await networking.get("/get", parameters: parameters)

        switch result {
        case .success(_):
            print("Test passed")
        case .failure(let error):
            print("error \(error)")
        }
    }

    func testNewPOST() async throws {
        let networking = Networking(baseURL: baseURL)

        let result: Result<Void, NetworkingError> = await networking.post("/get", parameters: ["String": "String"])

        switch result {
        case .success(_):
            print("worked")
        case .failure(let failure):
            print(failure.localizedDescription)
        }
    }

    func testNetworkingJSON() async throws {
        let networking = Networking(baseURL: baseURL)

        let result: Result<NetworkingResponse, NetworkingError> = await networking.get("/auth")
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

        let result: Result<NetworkingResponse, NetworkingError> = await networking.post("/auth", parameters: [:])
        switch result {
        case .success(_): break
        case .failure(let response):
            XCTAssertTrue(response.errorDescription!.contains("has already been taken"))
        }
    }
}
