import Foundation
import XCTest
@testable import Networking

class NetworkingIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testSetAuthorizationHeaderWithUsernameAndPassword() async throws {
        let networking = Networking(baseURL: baseURL)
        networking.setAuthorizationHeader(username: "user", password: "passwd")
        let result: Result<NetworkingResponse, NetworkingError> = await networking.get("/basic-auth/user/passwd")
        switch result {
        case let .success(response):
            XCTAssertEqual(response.body.string(for: "user"), "user")
            XCTAssertEqual(response.body.bool(for: "authenticated"), true)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testSetAuthorizationHeaderWithBearerToken() async throws {
        let networking = Networking(baseURL: baseURL)
        let token = "hi-mom"
        networking.setAuthorizationHeader(token: token)
        let result: Result<NetworkingResponse, NetworkingError> = await networking.post("/post")
        switch result {
        case let .success(response):
            let headers = httpbinEchoedMap(response, "headers")
            XCTAssertEqual("Bearer \(token)", headers["Authorization"])
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testHeaderField() async throws {
        let networking = Networking(baseURL: baseURL)
        networking.headerFields = ["HeaderKey": "HeaderValue"]
        let result: Result<NetworkingResponse, NetworkingError> = await networking.post("/post")
        switch result {
        case let .success(response):
            let headers = httpbinEchoedMap(response, "headers")
            XCTAssertEqual("HeaderValue", headers["Headerkey"])
        case let .failure(error):
            XCTFail(error.localizedDescription)
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
