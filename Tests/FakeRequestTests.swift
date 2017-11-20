import Foundation
import XCTest

class FakeRequestTests: XCTestCase {
    let baseURL = "http://httpbin.org"

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
        let existingRequests = [Networking.RequestType.get: ["/companies": request]]

        XCTAssertNil(FakeRequest.find(ofType: .get, forPath: "/users", in: existingRequests))
        XCTAssertNil(FakeRequest.find(ofType: .get, forPath: "/users", in: [:]))


    }

    func testOneLevelFind() {
        let json = [
            "name": "Name {userID}"
        ]
        let request = FakeRequest(response: json, responseType: .json, statusCode: 200)
        let existingRequests = [Networking.RequestType.get: ["/users/{userID}": request]]
        let result = FakeRequest.find(ofType: .get, forPath: "/users/10", in: existingRequests)

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
        let existingRequests = [Networking.RequestType.get: ["/users/{userID}/companies/{companyID}": request]]
        let result = FakeRequest.find(ofType: .get, forPath: "/users/10/companies/20", in: existingRequests)

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
        let existingRequests = [Networking.RequestType.get: ["/users/{userID}/companies/{companyID}/products/{productID}": request]]
        let result = FakeRequest.find(ofType: .get, forPath: "/users/10/companies/20/products/30", in: existingRequests)

        let expected = [
            "user": "User 10",
            "company": "Company 20",
            "product": "Product 30"
        ]

        XCTAssertEqual(result?.response as? NSDictionary, expected as NSDictionary)
    }
}

// GET tests
extension FakeRequestTests {
    func testFakeGET() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/stories", response: ["name": "Elvis"])

        networking.get("/stories") { result in
            switch result {
            case let .success(response):
                let json = response.dictionaryBody
                let value = json["name"] as? String
                XCTAssertEqual(value, "Elvis")
            case .failure:
                XCTFail()
            }
        }
    }

    func testFakeGETWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/stories", response: nil, statusCode: 401)

        networking.get("/stories") { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                XCTAssertEqual(response.error.code, 401)
            }
        }
    }

    func testFakeGETWithInvalidPathAndJSONError() {
        let networking = Networking(baseURL: baseURL)

        let expectedResponse = ["error_message": "Shit went down"]
        networking.fakeGET("/stories", response: expectedResponse, statusCode: 401)

        networking.get("/stories") { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                let json = response.dictionaryBody
                XCTAssertEqual(json as! [String: String], expectedResponse)
                XCTAssertEqual(response.error.code, 401)
            }
        }
    }

    func testFakeGETUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/entries", fileName: "entries.json", bundle: Bundle(for: GETTests.self))

        networking.get("/entries") { result in
            switch result {
            case let .success(response):
                let json = response.arrayBody
                let entry = json[0]
                let value = entry["title"] as? String
                XCTAssertEqual(value, "Entry 1")
            case .failure:
                XCTFail()
            }
        }
    }

    func testFakeGETUsingPattern() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/users/{userID}", fileName: "user.json", bundle: Bundle(for: GETTests.self))

        networking.get("/users/10") { result in
            switch result {
            case .success(let response):
                let json = response.dictionaryBody
                let id = json["id"] as? String
                XCTAssertEqual(id, "10")

                let name = json["name"] as? String
                XCTAssertEqual(name, "Name 10")
            case .failure:
                XCTFail()
            }
        }

        networking.get("/users/20") { result in
            switch result {
            case .success(let response):
                let json = response.dictionaryBody
                let id = json["id"] as? String
                XCTAssertEqual(id, "20")

                let name = json["name"] as? String
                XCTAssertEqual(name, "Name 20")
            case .failure:
                XCTFail()
            }
        }
    }
}

// POST tests
extension FakeRequestTests {
    func testFakePOST() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/story", response: [["name": "Elvis"]])

        networking.post("/story", parameters: ["username": "jameson", "password": "secret"]) { result in
            switch result {
            case let .success(response):
                let json = response.arrayBody
                let value = json[0]["name"] as? String
                XCTAssertEqual(value, "Elvis")
            case .failure:
                XCTFail()
            }
        }
    }

    func testFakePOSTWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/story", response: nil, statusCode: 401)

        networking.post("/story") { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                XCTAssertEqual(response.error.code, 401)
            }
        }
    }

    func testFakePOSTUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/entries", fileName: "entries.json", bundle: Bundle(for: POSTTests.self))

        networking.post("/entries") { result in
            switch result {
            case let .success(response):
                let json = response.arrayBody
                let entry = json[0]
                let value = entry["title"] as? String
                XCTAssertEqual(value, "Entry 1")
            case .failure:
                XCTFail()
            }
        }
    }
}

// PUT tests
extension FakeRequestTests {
    func testFakePUT() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/story", response: [["name": "Elvis"]])

        networking.put("/story", parameters: ["username": "jameson", "password": "secret"]) { result in
            switch result {
            case let .success(response):
                let json = response.arrayBody
                let value = json[0]["name"] as? String
                XCTAssertEqual(value, "Elvis")
            case .failure:
                XCTFail()
            }
        }
    }

    func testFakePUTWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/story", response: nil, statusCode: 401)

        networking.put("/story", parameters: nil) { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                XCTAssertEqual(response.error.code, 401)
            }
        }
    }

    func testFakePUTUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/entries", fileName: "entries.json", bundle: Bundle(for: PUTTests.self))

        networking.put("/entries", parameters: nil) { result in
            switch result {
            case let .success(response):
                let json = response.arrayBody
                let entry = json[0]
                let value = entry["title"] as? String
                XCTAssertEqual(value, "Entry 1")
            case .failure:
                XCTFail()
            }
        }
    }
}

// DELETE tests
extension FakeRequestTests {
    func testFakeDELETE() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/stories", response: ["name": "Elvis"])

        networking.delete("/stories") { result in
            switch result {
            case let .success(response):
                let json = response.dictionaryBody
                let value = json["name"] as? String
                XCTAssertEqual(value, "Elvis")
            case .failure:
                XCTFail()
            }
        }
    }

    func testFakeDELETEWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/story", response: nil, statusCode: 401)

        networking.delete("/story") { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                XCTAssertEqual(response.error.code, 401)
            }
        }
    }

    func testFakeDELETEUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/entries", fileName: "entries.json", bundle: Bundle(for: DELETETests.self))

        networking.delete("/entries") { result in
            switch result {
            case let .success(response):
                let json = response.arrayBody
                let entry = json[0]
                let value = entry["title"] as? String
                XCTAssertEqual(value, "Entry 1")
            case .failure:
                XCTFail()
            }
        }
    }
}
