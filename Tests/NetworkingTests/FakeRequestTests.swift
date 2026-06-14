import Foundation
import XCTest
@testable import Networking

class FakeRequestTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    // Decodes a fake request's JSON payload back into a dictionary so `find`'s template
    // substitution can be asserted against the typed `.data` payload.
    private func decodedDictionary(_ request: FakeRequest?) -> NSDictionary? {
        guard case let .data(data)? = request?.payload else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? NSDictionary
    }

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
        let request = FakeRequest(payload: .none, responseType: .json, headerFields: nil, statusCode: 200, delay: 0)
        let existingRequests = [Networking.RequestType.get: ["/companies": request]]

        XCTAssertNil(try FakeRequest.find(ofType: .get, forPath: "/users", in: existingRequests))
        XCTAssertNil(try FakeRequest.find(ofType: .get, forPath: "/users", in: [:]))
    }

    func testOneLevelFind() throws {
        let json = [
            "name": "Name {userID}"
        ]
        let request = FakeRequest(payload: .data(try JSONSerialization.data(withJSONObject: json)), responseType: .json, headerFields: nil, statusCode: 200, delay: 0)
        let existingRequests = [Networking.RequestType.get: ["/users/{userID}": request]]
        let result = try FakeRequest.find(ofType: .get, forPath: "/users/10", in: existingRequests)

        let expected = [
            "name": "Name 10"
        ]

        XCTAssertEqual(decodedDictionary(result), expected as NSDictionary)
    }

    func testOneLevelFindFailureBecauseOfDictionary() throws {
        let json = [
            "name": "Name {userID}"
        ]
        let request = FakeRequest(payload: .data(try JSONSerialization.data(withJSONObject: json)), responseType: .json, headerFields: nil, statusCode: 200, delay: 0)
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

        XCTAssertEqual(decodedDictionary(result), expected as NSDictionary)
    }

    func testTwoLevelFind() throws {
        let json = [
            "user": "User {userID}",
            "company": "Company {companyID}"
        ]
        let request = FakeRequest(payload: .data(try JSONSerialization.data(withJSONObject: json)), responseType: .json, headerFields: nil, statusCode: 200, delay: 0)
        let existingRequests = [Networking.RequestType.get: ["/users/{userID}/companies/{companyID}": request]]
        let result = try FakeRequest.find(ofType: .get, forPath: "/users/10/companies/20", in: existingRequests)

        let expected = [
            "user": "User 10",
            "company": "Company 20"
        ]

        XCTAssertEqual(decodedDictionary(result), expected as NSDictionary)
    }

    func testThreeLevelFind() throws {
        let json = [
            "user": "User {userID}",
            "company": "Company {companyID}",
            "product": "Product {productID}"
        ]
        let request = FakeRequest(payload: .data(try JSONSerialization.data(withJSONObject: json)), responseType: .json, headerFields: nil, statusCode: 200, delay: 0)
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

        XCTAssertEqual(decodedDictionary(result), expected as NSDictionary)
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

        let request = FakeRequest(payload: .data(try JSONSerialization.data(withJSONObject: json)), responseType: .json, headerFields: nil, statusCode: 200, delay: 0)
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
        XCTAssertEqual(decodedDictionary(result), expected as NSDictionary)
    }
}

// GET tests
extension FakeRequestTests {
    func testFakeGET() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakeGET("/stories", response: ["name": "Elvis"])

        let result: Result<JSONResponse, NetworkingError> = await networking.get("/stories")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "name"), "Elvis")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testGETWithDelay() async throws {
        let networking = Networking(baseURL: baseURL)
        let delay: Double = 2.0

        let startTime1 = Date()
        await networking.fakeGET("/stories", response: ["name": "Elvis"], delay: delay)

        let firstResult: Result<JSONResponse, NetworkingError> = await networking.get("/stories")
        let endTime1 = Date()
        let elapsedTime1 = endTime1.timeIntervalSince(startTime1)
        XCTAssertGreaterThanOrEqual(elapsedTime1, delay, "The delay was not correctly applied")

        switch firstResult {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "name"), "Elvis")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testFakeGETWithInvalidStatusCode() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakeGET("/stories", statusCode: 401)

        let result: Result<JSONResponse, NetworkingError> = await networking.get("/stories")
        switch result {
        case .success:
            XCTFail()
        case let .failure(error):
            guard case let .http(httpError) = error else {
                return XCTFail("expected an HTTP error, got \(error)")
            }
            XCTAssertEqual(httpError.statusCode, 401)
        }
    }

    func testFakeGETWithInvalidPathAndJSONError() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakeGET("/stories", response: ["error": "Shit went down"], statusCode: 401)

        let result: Result<JSONResponse, NetworkingError> = await networking.get("/stories")
        switch result {
        case .success:
            XCTFail()
        case let .failure(error):
            guard case let .http(httpError) = error else {
                return XCTFail("expected an HTTP error, got \(error)")
            }
            XCTAssertEqual(httpError.statusCode, 401)
            XCTAssertTrue(httpError.serverMessage?.contains("Shit went down") ?? false)
        }
    }

    func testFakeGETUsingFile() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakeGET("/entries", fileName: "entries.json", bundle: .module)

        let result: Result<[[String: AnyCodable]], NetworkingError> = await networking.get("/entries")
        switch result {
        case let .success(entries):
            XCTAssertEqual(entries.first?.string(for: "title"), "Entry 1")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testFakeGETOneLevelUsingPattern() async throws {
        let networking = Networking(baseURL: baseURL)

        let json = [
            "name": "Name {userID}"
        ]

        await networking.fakeGET("/users/ados", response: json, statusCode: 200)
        await networking.fakeGET("/users/bedos", response: json, statusCode: 200)
        await networking.fakeGET("/users/cedos", response: json, statusCode: 200)
        await networking.fakeGET("/users/tedos", response: json, statusCode: 200)
        await networking.fakeGET("/users/melos", response: json, statusCode: 200)
        await networking.fakeGET("/users/{userID}", response: json, statusCode: 200)

        let result: Result<JSONResponse, NetworkingError> = await networking.get("/users/10")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "name"), "Name 10")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }

        let result2: Result<JSONResponse, NetworkingError> = await networking.get("/users/20")
        switch result2 {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "name"), "Name 20")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testFakeGETUsingHeader() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakeGET("/story", response: ["ok": true], headerFields: ["uid": "12345678"])

        let result: Result<JSONResponse, NetworkingError> = await networking.get("/story")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.headers.string(for: "uid"), "12345678")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }
}

// POST tests
extension FakeRequestTests {
    func testFakePOST() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakePOST("/story", response: [["name": "Elvis"]])

        let result: Result<[[String: AnyCodable]], NetworkingError> = await networking.post("/story", body: ["username": "jameson", "password": "secret"])
        switch result {
        case let .success(stories):
            XCTAssertEqual(stories.first?.string(for: "name"), "Elvis")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testFakePOSTWithInvalidStatusCode() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakePOST("/story", statusCode: 401)

        let result: Result<JSONResponse, NetworkingError> = await networking.post("/story")
        switch result {
        case .success:
            XCTFail()
        case let .failure(error):
            guard case let .http(httpError) = error else {
                return XCTFail("expected an HTTP error, got \(error)")
            }
            XCTAssertEqual(httpError.statusCode, 401)
        }
    }

    func testFakePOSTUsingFile() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakePOST("/entries", fileName: "entries.json", bundle: .module)

        let result: Result<[[String: AnyCodable]], NetworkingError> = await networking.post("/entries")
        switch result {
        case let .success(entries):
            XCTAssertEqual(entries.first?.string(for: "title"), "Entry 1")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testFakePOSTUsingHeader() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakePOST("/story", headerFields: ["uid": "12345678"])

        let result: Result<JSONResponse, NetworkingError> = await networking.post("/story")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.headers.string(for: "uid"), "12345678")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testFakePOSTMultiple() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakeGET("/g/1/1", response: ["id":"2"])
        await networking.fakeGET("/g/2/2", response: ["id":"2"])
        await networking.fakePOST("/g/1/e", response: ["id":"2"])
        await networking.fakePOST("/g/1/b", response: ["id":"5"])
        await networking.fakePOST("/g/5/f")
        await networking.fakePUT("/g/2/2", response: ["id":"2"])
        await networking.fakePOST("/g/x/o", response: ["id":"3"])
        await networking.fakePOST("/g/1/b", response: ["id":"4"])
        await networking.fakeDELETE("/g/2/2")
        await networking.fakePOST("/g/1/b", response: ["id":"1"])

        let result: Result<JSONResponse, NetworkingError> = await networking.post("/g/1/b", body: ["ignored": true])
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "id"), "1")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }
}

// PUT tests
extension FakeRequestTests {
    func testFakePUT() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakePUT("/story", response: [["name": "Elvis"]])

        let result: Result<[[String: AnyCodable]], NetworkingError> = await networking.put("/story", body: ["username": "jameson", "password": "secret"])
        switch result {
        case let .success(stories):
            XCTAssertEqual(stories.first?.string(for: "name"), "Elvis")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testFakePUTWithInvalidStatusCode() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakePUT("/story", statusCode: 401)

        let result: Result<JSONResponse, NetworkingError> = await networking.put("/story")
        switch result {
        case .success:
            XCTFail()
        case let .failure(error):
            guard case let .http(httpError) = error else {
                return XCTFail("expected an HTTP error, got \(error)")
            }
            XCTAssertEqual(httpError.statusCode, 401)
        }
    }

    func testFakePUTUsingFile() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakePUT("/entries", fileName: "entries.json", bundle: .module)

        let result: Result<[[String: AnyCodable]], NetworkingError> = await networking.put("/entries")
        switch result {
        case let .success(entries):
            XCTAssertEqual(entries.first?.string(for: "title"), "Entry 1")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testFakePUTUsingHeader() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakePUT("/story", headerFields: ["uid": "12345678"])

        let result: Result<JSONResponse, NetworkingError> = await networking.put("/story")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.headers.string(for: "uid"), "12345678")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }
}

// PATCH tests
extension FakeRequestTests {
    func testFakePATCH() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakePATCH("/story", response: [["name": "Elvis"]])

        let result: Result<[[String: AnyCodable]], NetworkingError> = await networking.patch("/story", body: ["username": "jameson", "password": "secret"])
        switch result {
        case let .success(stories):
            XCTAssertEqual(stories.first?.string(for: "name"), "Elvis")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testFakePATCHWithInvalidStatusCode() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakePATCH("/story", statusCode: 401)

        let result: Result<JSONResponse, NetworkingError> = await networking.patch("/story")
        switch result {
        case .success:
            XCTFail()
        case let .failure(error):
            guard case let .http(httpError) = error else {
                return XCTFail("expected an HTTP error, got \(error)")
            }
            XCTAssertEqual(httpError.statusCode, 401)
        }
    }

    func testFakePATCHUsingFile() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakePATCH("/entries", fileName: "entries.json", bundle: .module)

        let result: Result<[[String: AnyCodable]], NetworkingError> = await networking.patch("/entries")
        switch result {
        case let .success(entries):
            XCTAssertEqual(entries.first?.string(for: "title"), "Entry 1")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testFakePATCHUsingHeader() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakePATCH("/story", headerFields: ["uid": "12345678"])

        let result: Result<JSONResponse, NetworkingError> = await networking.patch("/story")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.headers.string(for: "uid"), "12345678")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }
}

// DELETE tests
extension FakeRequestTests {
    func testFakeDELETE() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakeDELETE("/stories", response: ["name": "Elvis"])

        let result: Result<JSONResponse, NetworkingError> = await networking.delete("/stories")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "name"), "Elvis")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testFakeDELETEMultiple() async {
        let networking = Networking(baseURL: baseURL)

        await networking.fakeDELETE("/a/1/b/1")
        await networking.fakeDELETE("/a/1/b/2")
        await networking.fakeDELETE("/a/1/b/3")
        await networking.fakeDELETE("/a/1/b/4")
        await networking.fakeDELETE("/a/1/b/5")
        await networking.fakeDELETE("/a/1/b/6")
        await networking.fakeDELETE("/a/1/b/7")
        await networking.fakeDELETE("/a/1/b/8")
        await networking.fakeDELETE("/a/1/b/9")
        await networking.fakeDELETE("/a/1/b/10")
        await networking.fakeDELETE("/a/1/b/11")

        let result: Result<JSONResponse, NetworkingError> = await networking.delete("/a/1/b/5")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.statusCode, 200)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testFakeDELETEWithInvalidStatusCode() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakeDELETE("/story", statusCode: 401)

        let result: Result<JSONResponse, NetworkingError> = await networking.delete("/story")
        switch result {
        case .success:
            XCTFail()
        case let .failure(error):
            guard case let .http(httpError) = error else {
                return XCTFail("expected an HTTP error, got \(error)")
            }
            XCTAssertEqual(httpError.statusCode, 401)
        }
    }

    func testFakeDELETEUsingFile() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakeDELETE("/entries", fileName: "entries.json", bundle: .module)

        let result: Result<[[String: AnyCodable]], NetworkingError> = await networking.delete("/entries")
        switch result {
        case let .success(entries):
            XCTAssertEqual(entries.first?.string(for: "title"), "Entry 1")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testFakeDELETEUsingHeader() async throws {
        let networking = Networking(baseURL: baseURL)

        await networking.fakeDELETE("/story", headerFields: ["uid": "12345678"])

        let result: Result<JSONResponse, NetworkingError> = await networking.delete("/story")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.headers.string(for: "uid"), "12345678")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }
}

// Image tests
extension FakeRequestTests {
    func testFakeImageDownload() async throws {
        let networking = Networking(baseURL: baseURL)
        let pigImage = Image.find(named: "pig.png", inBundle: .module)
        await networking.fakeImageDownload("/image/png", image: pigImage)
        let result: Result<Image, NetworkingError> = await networking.downloadImage("/image/png")
        switch result {
        case let .success(image):
            XCTAssertEqual(pigImage.pngData(), image.pngData())
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testFakeImageDownloadWithDelay() async throws {
        let networking = Networking(baseURL: baseURL)
        let pigImage = Image.find(named: "pig.png", inBundle: .module)
        let delay: Double = 2.0

        let startTime = Date()
        await networking.fakeImageDownload("/image/png", image: pigImage, delay: delay)

        let result: Result<Image, NetworkingError> = await networking.downloadImage("/image/png")
        let endTime = Date()
        let elapsedTime = endTime.timeIntervalSince(startTime)
        XCTAssertGreaterThanOrEqual(elapsedTime, delay, "The delay was not correctly applied")

        switch result {
        case let .success(image):
            XCTAssertEqual(pigImage.pngData(), image.pngData())
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testFakeImageDownloadWithInvalidStatusCode() async throws {
        let networking = Networking(baseURL: baseURL)
        let pigImage = Image.find(named: "pig.png", inBundle: .module)
        await networking.fakeImageDownload("/image/png", image: pigImage, statusCode: 401)
        let result: Result<Image, NetworkingError> = await networking.downloadImage("/image/png")
        switch result {
        case .success:
            XCTFail()
        case let .failure(error):
            guard case let .http(httpError) = error else {
                return XCTFail("expected an HTTP error, got \(error)")
            }
            XCTAssertEqual(httpError.statusCode, 401)
        }
    }

    // The envelope form keeps the response headers reachable for image downloads.
    func testFakeImageDownloadUsingHeader() async throws {
        let networking = Networking(baseURL: baseURL)
        let pigImage = Image.find(named: "pig.png", inBundle: .module)
        await networking.fakeImageDownload("/image/png", image: pigImage, headerFields: ["uid": "12345678"])
        let result: Result<ImageResponse, NetworkingError> = await networking.downloadImage("/image/png")
        switch result {
        case let .success(response):
            XCTAssertEqual(pigImage.pngData(), response.image.pngData())
            XCTAssertEqual(response.headers.string(for: "uid"), "12345678")
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testNewPostWithFakeHeaders() async {
        let networking = Networking(baseURL: baseURL)

        await networking.fakePOST("/auth/verify_confirmation_code", response: [
            "phone_number": "phoneNumber"
        ], headerFields: [
            "client": "aClient",
            "access-token": "anAccessToken",
            "uid": "aUID",
            "Authorization": "authorization",
        ])

        let parameters = [
            "phone_number": "phoneNumber",
            "confirmation_code": "confirmationCode"
        ]

        let result: Result<JSONResponse, NetworkingError> = await networking.post("/auth/verify_confirmation_code", body: parameters)
        switch result {
        case .success(let response):
            let headers = response.headers
            XCTAssertEqual(headers.string(for: "access-token"), "anAccessToken")
            XCTAssertEqual(headers.string(for: "client"), "aClient")
            XCTAssertEqual(headers.string(for: "uid"), "aUID")
            XCTAssertEqual(headers.string(for: "Authorization"), "authorization")

            let body = response.body
            XCTAssertEqual(body.string(for: "phone_number"), "phoneNumber")
        case .failure (let response):
            XCTFail(response.localizedDescription)
        }
    }
}
