import Foundation
import XCTest
@testable import Networking

class NetworkingIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testSetAuthorizationHeaderWithUsernameAndPassword() async throws {
        let networking = Networking(baseURL: baseURL)
        networking.setAuthorizationHeader(username: "user", password: "passwd")
        let result = try await networking.oldGet("/basic-auth/user/passwd")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            let user = json["user"] as? String
            let authenticated = json["authenticated"] as? Bool
            XCTAssertEqual(user, "user")
            XCTAssertEqual(authenticated, true)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testSetAuthorizationHeaderWithBearerToken() async throws {
        let networking = Networking(baseURL: baseURL)
        let token = "hi-mom"
        networking.setAuthorizationHeader(token: token)
        let result = try await networking.oldPost("/post")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            let headers = httpbinEchoedMap(json, "headers")
            XCTAssertEqual("Bearer \(token)", headers["Authorization"])
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testHeaderField() async throws {
        let networking = Networking(baseURL: baseURL)
        networking.headerFields = ["HeaderKey": "HeaderValue"]
        let result = try await networking.oldPost("/post")
        switch result {
        case let .success(response):
            let json = response.dictionaryBody
            let headers = httpbinEchoedMap(json, "headers")
            XCTAssertEqual("HeaderValue", headers["Headerkey"])
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testDeleteCachedFiles() async throws {
        let directory = FileManager.SearchPathDirectory.cachesDirectory
        let cachesURL = FileManager.default.urls(for: directory, in: .userDomainMask).first!
        let folderURL = cachesURL.appendingPathComponent(URL(string: Networking.domain)!.absoluteString)

        let networking = Networking(baseURL: baseURL)
        _ = try await networking.downloadImage("/image/png")
        let image = Image.find(named: "sample.jpg", inBundle: .module)
        let data = image.jpgData()
        let filename = cachesURL.appendingPathComponent("sample.jpg")
        ((try data?.write(to: filename)) as ()??)

        XCTAssertTrue(FileManager.default.exists(at: cachesURL))
        XCTAssertTrue(FileManager.default.exists(at: folderURL))
        XCTAssertTrue(FileManager.default.exists(at: filename))

        try Networking.deleteCachedFiles()

        // Caches folder should be there
        XCTAssertTrue(FileManager.default.exists(at: cachesURL))

        // Files under networking domain are gone
        XCTAssertFalse(FileManager.default.exists(at: folderURL))

        // Saved image should be there
        XCTAssertTrue(FileManager.default.exists(at: filename))
    }
}
