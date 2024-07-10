import Foundation
import XCTest
@testable import Networking

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

    func testFind() throws {
        let request = FakeRequest(response: nil, responseType: .json, headerFields: nil, statusCode: 200, delay: 0)
        let existingRequests = [Networking.RequestType.get: ["/companies": request]]

        XCTAssertNil(try FakeRequest.find(ofType: .get, forPath: "/users", in: existingRequests))
        XCTAssertNil(try FakeRequest.find(ofType: .get, forPath: "/users", in: [:]))
    }

    func testOneLevelFind() throws {
        let json = [
            "name": "Name {userID}"
        ]
        let request = FakeRequest(response: json, responseType: .json, headerFields: nil, statusCode: 200, delay: 0)
        let existingRequests = [Networking.RequestType.get: ["/users/{userID}": request]]
        let result = try FakeRequest.find(ofType: .get, forPath: "/users/10", in: existingRequests)

        let expected = [
            "name": "Name 10"
        ]

        XCTAssertEqual(result?.response as? NSDictionary, expected as NSDictionary)
    }

    func testOneLevelFindFailureBecauseOfDictionary() throws {
        let json = [
            "name": "Name {userID}"
        ]
        let request = FakeRequest(response: json, responseType: .json, headerFields: nil, statusCode: 200, delay: 0)
        let existingRequests = [
            Networking.RequestType.get: [
                "/users/ados": request,
                "/users/bedos": request,
                "/users/cedos": request,
                "/users/tedos": request,
                "/users/melos": request,
                "/users/{userID}": request
            ]
        ]
        let result = try FakeRequest.find(ofType: .get, forPath: "/users/10", in: existingRequests)

        let expected = [
            "name": "Name 10"
        ]

        XCTAssertEqual(result?.response as? NSDictionary, expected as NSDictionary)
    }

    func testTwoLevelFind() throws {
        let json = [
            "user": "User {userID}",
            "company": "Company {companyID}"
        ]
        let request = FakeRequest(response: json, responseType: .json, headerFields: nil, statusCode: 200, delay: 0)
        let existingRequests = [Networking.RequestType.get: ["/users/{userID}/companies/{companyID}": request]]
        let result = try FakeRequest.find(ofType: .get, forPath: "/users/10/companies/20", in: existingRequests)

        let expected = [
            "user": "User 10",
            "company": "Company 20"
        ]

        XCTAssertEqual(result?.response as? NSDictionary, expected as NSDictionary)
    }

    func testThreeLevelFind() throws {
        let json = [
            "user": "User {userID}",
            "company": "Company {companyID}",
            "product": "Product {productID}"
        ]
        let request = FakeRequest(response: json, responseType: .json, headerFields: nil, statusCode: 200, delay: 0)
        let existingRequests = [Networking.RequestType.get: [
            "/users/{userID}/companies/{companyID}/products/a": request,
            "/users/{userID}/companies/{companyID}/products/b": request,
            "/users/{userID}/companies/{companyID}/products/c": request,
            "/users/{userID}/companies/{companyID}/products/d": request,
            "/users/{userID}/companies/{companyID}/products/{productID}": request,
            "/users/{userID}/companies/{companyID}/products/e": request,
            "/users/{userID}/companies/{companyID}/products/f": request,
            "/users/{userID}/companies/{companyID}/products/g": request,
        ]]
        let result = try FakeRequest.find(ofType: .get, forPath: "/users/10/companies/20/products/30", in: existingRequests)

        let expected = [
            "user": "User 10",
            "company": "Company 20",
            "product": "Product 30"
        ]

        XCTAssertEqual(result?.response as? NSDictionary, expected as NSDictionary)
    }

    func testTenLevelFind() throws {
        let json = [
            "resource1": "Resource {resourceID1}",
            "resource2": "Resource {resourceID2}",
            "resource3": "Resource {resourceID3}",
            "resource4": "Resource {resourceID4}",
            "resource5": "Resource {resourceID5}",
            "resource6": "Resource {resourceID6}",
            "resource7": "Resource {resourceID7}",
            "resource8": "Resource {resourceID8}",
            "resource9": "Resource {resourceID9}",
            "resource10": "Resource {resourceID10}",
        ]

        let request = FakeRequest(response: json, responseType: .json, headerFields: nil, statusCode: 200, delay: 0)
        let existingRequests = [Networking.RequestType.get: ["resource1/{resourceID1}/resource2/{resourceID2}/resource3/{resourceID3}/resource4/{resourceID4}/resource5/{resourceID5}/resource6/{resourceID6}/resource7/{resourceID7}/resource8/{resourceID8}/resource9/{resourceID9}/resource10/{resourceID10}": request]]
        let result = try FakeRequest.find(ofType: .get, forPath: "resource1/1/resource2/2/resource3/3/resource4/4/resource5/5/resource6/6/resource7/7/resource8/8/resource9/9/resource10/10", in: existingRequests)
        let expected = [
            "resource1": "Resource 1",
            "resource2": "Resource 2",
            "resource3": "Resource 3",
            "resource4": "Resource 4",
            "resource5": "Resource 5",
            "resource6": "Resource 6",
            "resource7": "Resource 7",
            "resource8": "Resource 8",
            "resource9": "Resource 9",
            "resource10": "Resource 10",
            ]
        XCTAssertEqual(result?.response as? NSDictionary, expected as NSDictionary)
    }
}

// GET tests
extension FakeRequestTests {
    func testFakeGET() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/stories", response: ["name": "Elvis"])

        let result = try await networking.get("/stories")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            let value = json["name"] as? String
            XCTAssertEqual(value, "Elvis")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testFakeGETWithInvalidStatusCode() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/stories", response: nil, statusCode: 401)

        let result = try await networking.get("/stories")
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertEqual(response.error.code, 401)
        }
    }

    func testFakeGETWithInvalidPathAndJSONError() async throws {
        let networking = Networking(baseURL: baseURL)

        let expectedResponse = ["error_message": "Shit went down"]
        networking.fakeGET("/stories", response: expectedResponse, statusCode: 401)

        let result = try await networking.get("/stories")
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            let json = response.dictionaryBody
            XCTAssertEqual(json as! [String: String], expectedResponse)
            XCTAssertEqual(response.error.code, 401)
        }
    }

    func testFakeGETUsingFile() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/entries", fileName: "entries.json", bundle: .module)

        let result = try await networking.get("/entries")
        switch result {
        case let .success(response):
            let json = response.arrayBody
            let entry = json[0]
            let value = entry["title"] as? String
            XCTAssertEqual(value, "Entry 1")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testFakeGETOneLevelUsingPattern() async throws {
        let networking = Networking(baseURL: baseURL)

        let json = [
            "name": "Name {userID}"
        ]

        networking.fakeGET("/users/ados", response: json, statusCode: 200)
        networking.fakeGET("/users/bedos", response: json, statusCode: 200)
        networking.fakeGET("/users/cedos", response: json, statusCode: 200)
        networking.fakeGET("/users/tedos", response: json, statusCode: 200)
        networking.fakeGET("/users/melos", response: json, statusCode: 200)
        networking.fakeGET("/users/{userID}", response: json, statusCode: 200)

        let result = try await networking.get("/users/10")
        switch result {
        case .success(let response):
            let json = response.dictionaryBody
            let name = json["name"] as? String
            XCTAssertEqual(name, "Name 10")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }

        let result2 = try await networking.get("/users/20")
        switch result2 {
        case .success(let response):
            let json = response.dictionaryBody
            let name = json["name"] as? String
            XCTAssertEqual(name, "Name 20")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testFakeGETUsingHeader() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/story", response: nil, headerFields: ["uid": "12345678"])

        let result = try await networking.get("/story")
        switch result {
        case let .success(response):
            let headers = response.headers
            XCTAssertEqual(headers["uid"] as! String, "12345678")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }
}

// POST tests
extension FakeRequestTests {
    func testFakePOST() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/story", response: [["name": "Elvis"]])

        let result = try await networking.post("/story", parameters: ["username": "jameson", "password": "secret"])
        switch result {
        case let .success(response):
            let json = response.arrayBody
            let value = json[0]["name"] as? String
            XCTAssertEqual(value, "Elvis")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testFakePOSTWithInvalidStatusCode() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/story", response: nil, statusCode: 401)

        let result = try await networking.post("/story")
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertEqual(response.error.code, 401)
        }
    }

    func testFakePOSTUsingFile() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/entries", fileName: "entries.json", bundle: .module)

        let result = try await networking.post("/entries")
        switch result {
        case let .success(response):
            let json = response.arrayBody
            let entry = json[0]
            let value = entry["title"] as? String
            XCTAssertEqual(value, "Entry 1")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testFakePOSTUsingHeader() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakePOST("/story", response: nil, headerFields: ["uid": "12345678"])

        let result = try await networking.post("/story")
        switch result {
        case let .success(response):
            let headers = response.headers
            XCTAssertEqual(headers["uid"] as! String, "12345678")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testFakePOSTMultiple() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakeGET("/g/1/1", response: ["id":"2"])
        networking.fakeGET("/g/2/2", response: ["id":"2"])
        networking.fakePOST("/g/1/e", response: ["id":"2"])
        networking.fakePOST("/g/1/b", response: ["id":"5"])
        networking.fakePOST("/g/5/f", response: nil)
        networking.fakePUT("/g/2/2", response: ["id":"2"])
        networking.fakePOST("/g/x/o", response: ["id":"3"])
        networking.fakePOST("/g/1/b", response: ["id":"4"])
        networking.fakeDELETE("/g/2/2", response: nil)
        networking.fakePOST("/g/1/b", response: ["id":"1"])

        let result = try await networking.post("/g/1/b", parameters: ["ignored": true])
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            let value = json["id"] as! String
            XCTAssertEqual(value, "1")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }
}

// PUT tests
extension FakeRequestTests {
    func testFakePUT() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/story", response: [["name": "Elvis"]])

        let result = try await networking.put("/story", parameters: ["username": "jameson", "password": "secret"])
        switch result {
        case let .success(response):
            let json = response.arrayBody
            let value = json[0]["name"] as? String
            XCTAssertEqual(value, "Elvis")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testFakePUTWithInvalidStatusCode() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/story", response: nil, statusCode: 401)

        let result = try await networking.put("/story", parameters: nil)
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertEqual(response.error.code, 401)
        }
    }

    func testFakePUTUsingFile() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/entries", fileName: "entries.json", bundle: .module)

        let result = try await networking.put("/entries", parameters: nil)
        switch result {
        case let .success(response):
            let json = response.arrayBody
            let entry = json[0]
            let value = entry["title"] as? String
            XCTAssertEqual(value, "Entry 1")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testFakePUTUsingHeader() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakePUT("/story", response: nil, headerFields: ["uid": "12345678"])

        let result = try await networking.put("/story")
        switch result {
        case let .success(response):
            let headers = response.headers
            XCTAssertEqual(headers["uid"] as! String, "12345678")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }
}

// PATCH tests
extension FakeRequestTests {
    func testFakePATCH() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakePATCH("/story", response: [["name": "Elvis"]])

        let result = try await networking.patch("/story", parameters: ["username": "jameson", "password": "secret"])
        switch result {
        case let .success(response):
            let json = response.arrayBody
            let value = json[0]["name"] as? String
            XCTAssertEqual(value, "Elvis")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testFakePATCHWithInvalidStatusCode() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakePATCH("/story", response: nil, statusCode: 401)

        let result = try await networking.patch("/story", parameters: nil)
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertEqual(response.error.code, 401)
        }
    }

    func testFakePATCHUsingFile() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakePATCH("/entries", fileName: "entries.json", bundle: .module)

        let result = try await networking.patch("/entries", parameters: nil)
        switch result {
        case let .success(response):
            let json = response.arrayBody
            let entry = json[0]
            let value = entry["title"] as? String
            XCTAssertEqual(value, "Entry 1")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testFakePATCHUsingHeader() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakePATCH("/story", response: nil, headerFields: ["uid": "12345678"])

        let result = try await networking.patch("/story")
        switch result {
        case let .success(response):
            let headers = response.headers
            XCTAssertEqual(headers["uid"] as! String, "12345678")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }
}

// DELETE tests
extension FakeRequestTests {
    func testFakeDELETE() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/stories", response: ["name": "Elvis"])

        let result = try await networking.delete("/stories")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            let value = json["name"] as? String
            XCTAssertEqual(value, "Elvis")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testFakeDELETEMultiple() {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/a/1/b/1", response: nil)
        networking.fakeDELETE("/a/1/b/2", response: nil)
        networking.fakeDELETE("/a/1/b/3", response: nil)
        networking.fakeDELETE("/a/1/b/4", response: nil)
        networking.fakeDELETE("/a/1/b/5", response: nil)
        networking.fakeDELETE("/a/1/b/6", response: nil)
        networking.fakeDELETE("/a/1/b/7", response: nil)
        networking.fakeDELETE("/a/1/b/8", response: nil)
        networking.fakeDELETE("/a/1/b/9", response: nil)
        networking.fakeDELETE("/a/1/b/10", response: nil)
        networking.fakeDELETE("/a/1/b/11", response: nil)

        let expectation = self.expectation(description: "testFakeDELETEMultiple")

        Task {
            let result = try await networking.delete("/a/1/b/5")
            switch result {
            case let .success(response):
                XCTAssertEqual(response.statusCode, 200)
                expectation.fulfill()
            case let .failure(response):
                XCTFail(response.error.localizedDescription)
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testFakeDELETEWithInvalidStatusCode() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/story", response: nil, statusCode: 401)

        let result = try await networking.delete("/story")
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertEqual(response.error.code, 401)
        }
    }

    func testFakeDELETEUsingFile() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/entries", fileName: "entries.json", bundle: .module)

        let result = try await networking.delete("/entries")
        switch result {
        case let .success(response):
            let json = response.arrayBody
            let entry = json[0]
            let value = entry["title"] as? String
            XCTAssertEqual(value, "Entry 1")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testFakeDELETEUsingHeader() async throws {
        let networking = Networking(baseURL: baseURL)

        networking.fakeDELETE("/story", response: nil, headerFields: ["uid": "12345678"])

        let result = try await networking.delete("/story")
        switch result {
        case let .success(response):
            let headers = response.headers
            XCTAssertEqual(headers["uid"] as! String, "12345678")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }
}

// Image tests
extension FakeRequestTests {
    func testFakeImageDownload() async throws {
        let networking = Networking(baseURL: baseURL)
        let pigImage = Image.find(named: "pig.png", inBundle: .module)
        networking.fakeImageDownload("/image/png", image: pigImage)
        let result = try await networking.downloadImage("/image/png")
        switch result {
        case let .success(response):
            let pigImageData = pigImage.pngData()
            let imageData = response.image.pngData()
            XCTAssertEqual(pigImageData, imageData)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testFakeImageDownloadWithInvalidStatusCode() async throws {
        let networking = Networking(baseURL: baseURL)
        let pigImage = Image.find(named: "pig.png", inBundle: .module)
        networking.fakeImageDownload("/image/png", image: pigImage, statusCode: 401)
        let result = try await networking.downloadImage("/image/png")
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertEqual(response.error.code, 401)
        }
    }

    func testFakeImageDownloadUsingHeader() async throws {
        let networking = Networking(baseURL: baseURL)
        let pigImage = Image.find(named: "pig.png", inBundle: .module)
        networking.fakeImageDownload("/image/png", image: pigImage, headerFields: ["uid": "12345678"])
        let result = try await networking.downloadImage("/image/png")
        switch result {
        case let .success(response):
            let pigImageData = pigImage.pngData()
            let imageData = response.image.pngData()
            XCTAssertEqual(pigImageData, imageData)

            let headers = response.headers
            XCTAssertEqual(headers["uid"] as! String, "12345678")
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }
}
