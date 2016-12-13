import Foundation
import XCTest

class FakeRequestTests: XCTestCase {
    func testRemoveFirstLetterIfDash() {
        var evaluated = "/"
        evaluated.removeFirstLetterIfDash()
        XCTAssertEqual(evaluated, "")

        evaluated = "/user"
        evaluated.removeFirstLetterIfDash()
        XCTAssertEqual(evaluated, "user")

        evaluated = "/user/"
        evaluated.removeFirstLetterIfDash()
        XCTAssertEqual(evaluated, "user/")
    }

    func testRemoveLastLetterIfDash() {
        var evaluated = "/"
        evaluated.removeLastLetterIfDash()
        XCTAssertEqual(evaluated, "")

        evaluated = "user/"
        evaluated.removeLastLetterIfDash()
        XCTAssertEqual(evaluated, "user")

        evaluated = "/user/"
        evaluated.removeLastLetterIfDash()
        XCTAssertEqual(evaluated, "/user")
    }

    func testFind() {
        let request = FakeRequest(response: nil, responseType: .json, statusCode: 200)
        let existingRequests = [Networking.RequestType.GET: ["/companies": request]]

        XCTAssertNil(FakeRequest.find(ofType: .GET, forPath: "/users", in: existingRequests))
        XCTAssertNil(FakeRequest.find(ofType: .GET, forPath: "/users", in: [:]))


    }

    func testOneLevelFind() {
        let json = [
            "name": "Name {userID}"
        ]
        let request = FakeRequest(response: json, responseType: .json, statusCode: 200)
        let existingRequests = [Networking.RequestType.GET: ["/users/{userID}": request]]
        let result = FakeRequest.find(ofType: .GET, forPath: "/users/10", in: existingRequests)

        let expected = [
            "name": "Name 10"
        ]

        XCTAssertEqual(result?.response as? NSDictionary, expected as NSDictionary)
    }

    func testTwoLevelFind() {
        let json = [
            "user": "User {userID}",
            "company": "Company {companyID}"
        ]
        let request = FakeRequest(response: json, responseType: .json, statusCode: 200)
        let existingRequests = [Networking.RequestType.GET: ["/users/{userID}/companies/{companyID}": request]]
        let result = FakeRequest.find(ofType: .GET, forPath: "/users/10/companies/20", in: existingRequests)

        let expected = [
            "user": "User 10",
            "company": "Company 20"
        ]

        XCTAssertEqual(result?.response as? NSDictionary, expected as NSDictionary)
    }

    func testThreeLevelFind() {
        let json = [
            "user": "User {userID}",
            "company": "Company {companyID}",
            "product": "Product {productID}"
        ]
        let request = FakeRequest(response: json, responseType: .json, statusCode: 200)
        let existingRequests = [Networking.RequestType.GET: ["/users/{userID}/companies/{companyID}/products/{productID}": request]]
        let result = FakeRequest.find(ofType: .GET, forPath: "/users/10/companies/20/products/30", in: existingRequests)

        let expected = [
            "user": "User 10",
            "company": "Company 20",
            "product": "Product 30"
        ]

        XCTAssertEqual(result?.response as? NSDictionary, expected as NSDictionary)
    }
}
