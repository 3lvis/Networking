import CoreLocation
import Foundation
import XCTest

@testable import Networking

class NewNetworkingIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

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

        let query = [
            URLQueryItem(name: "pickup_latitude", value: "\(pickupCoordinate.latitude)"),
            URLQueryItem(name: "pickup_longitude", value: "\(pickupCoordinate.longitude)"),
            URLQueryItem(name: "delivery_latitude", value: "\(deliveryCoordinate.latitude)"),
            URLQueryItem(name: "delivery_longitude", value: "\(deliveryCoordinate.longitude)"),
        ]

        let result: Result<Friend, NetworkingError> = await networking.get("/get", query: query)

        switch result {
        case .success(_):
            print("Test passed")
        case .failure(let error):
            print("error \(error)")
        }
    }

    func testNewPOST() async throws {
        let networking = Networking(baseURL: baseURL)

        let result: Result<Void, NetworkingError> = await networking.post("/get", body: ["String": "String"])

        switch result {
        case .success(_):
            print("worked")
        case .failure(let failure):
            print(failure.localizedDescription)
        }
    }

    func testNetworkingJSON() async throws {
        let networking = Networking(baseURL: baseURL)

        let result: Result<JSONResponse, NetworkingError> = await networking.get("/auth")
        switch result {
        case .success(let success):
            _ = success.headers.string(for: "access-token")
            _ = success.body.string(for: "id")
        case .failure(let failure):
            print(failure.localizedDescription)
        }
    }
}
