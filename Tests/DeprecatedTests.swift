import Foundation
import XCTest

class DeprecatedTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testCancelWithRequestID() {
        let expectation = self.expectation(description: "testCancelAllRequests")
        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        var cancelledGET = false

        let requestID = networking.GET("/get") { json, error in
            cancelledGET = error?.code == URLError.cancelled.rawValue
            XCTAssertTrue(cancelledGET)

            if cancelledGET {
                expectation.fulfill()
            }
        }

        networking.cancel(with: requestID)

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelAllRequests() {
        let expectation = self.expectation(description: "testCancelAllRequests")
        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        var cancelledGET = false
        var cancelledPOST = false

        networking.GET("/get") { json, error in
            cancelledGET = error?.code == URLError.cancelled.rawValue
            XCTAssertTrue(cancelledGET)

            if cancelledGET && cancelledPOST {
                expectation.fulfill()
            }
        }

        networking.POST("/post") { json, error in
            cancelledPOST = error?.code == URLError.cancelled.rawValue
            XCTAssertTrue(cancelledPOST)

            if cancelledGET && cancelledPOST {
                expectation.fulfill()
            }
        }

        networking.cancelAllRequests()
        
        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelGETWithPath() {
        let expectation = self.expectation(description: "testCancelGET")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.GET("/get") { json, error in
            XCTAssertEqual(error?.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }

        networking.cancelGET("/get")

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelGETWithID() {
        let expectation = self.expectation(description: "testCancelGET")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        let requestID = networking.GET("/get") { json, error in
            XCTAssertEqual(error?.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }

        networking.cancel(with: requestID)

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelPOSTWithPath() {
        let expectation = self.expectation(description: "testCancelPOST")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.POST("/post", parameters: ["username": "jameson", "password": "secret"]) { json, error in
            XCTAssertEqual(error?.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }

        networking.cancelPOST("/post")

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelPOSTWithID() {
        let expectation = self.expectation(description: "testCancelPOST")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        let requestID = networking.POST("/post", parameters: ["username": "jameson", "password": "secret"]) { json, error in
            XCTAssertEqual(error?.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }

        networking.cancel(with: requestID)

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelPUTWithPath() {
        let expectation = self.expectation(description: "testCancelPUT")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.PUT("/put", parameters: ["username": "jameson", "password": "secret"]) { json, error in
            XCTAssertEqual(error?.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }

        networking.cancelPUT("/put")

        self.waitForExpectations(timeout: 150.0, handler: nil)
    }

    func testCancelPUTWithID() {
        let expectation = self.expectation(description: "testCancelPUT")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        let requestID = networking.PUT("/put", parameters: ["username": "jameson", "password": "secret"]) { json, error in
            XCTAssertEqual(error?.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }

		networking.cancel(with: requestID)

        self.waitForExpectations(timeout: 150.0, handler: nil)
    }

    func testCancelDELETEWithPath() {
        let expectation = self.expectation(description: "testCancelDELETE")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.DELETE("/delete") { json, error in
            XCTAssertEqual(error?.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }

        networking.cancelDELETE("/delete")

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testCancelDELETEWithID() {
        let expectation = self.expectation(description: "testCancelDELETE")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        let requestID = networking.DELETE("/delete") { json, error in
            XCTAssertEqual(error?.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }

        networking.cancel(with: requestID)

        self.waitForExpectations(timeout: 15.0, handler: nil)
    }
}
