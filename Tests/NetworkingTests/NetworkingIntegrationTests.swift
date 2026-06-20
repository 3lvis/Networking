import Foundation
import XCTest

@testable import Networking

class NetworkingIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testSetAuthorizationHeaderWithUsernameAndPassword() async throws {
        let networking = Networking(baseURL: baseURL)
        await networking.setAuthorizationHeader(username: "user", password: "passwd")
        let result: Result<JSONResponse, NetworkingError> = await networking.get("/basic-auth/user/passwd")
        switch result {
        case .success(let response):
            XCTAssertEqual(response.body.string(for: "user"), "user")
            XCTAssertEqual(response.body.bool(for: "authenticated"), true)
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }

    func testSetAuthorizationHeaderWithBearerToken() async throws {
        let networking = Networking(baseURL: baseURL)
        let token = "hi-mom"
        await networking.setAuthorizationHeader(token: token)
        let result: Result<JSONResponse, NetworkingError> = await networking.post("/post")
        switch result {
        case .success(let response):
            let headers = httpbinEchoedMap(response, "headers")
            XCTAssertEqual("Bearer \(token)", headers["Authorization"])
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }

    func testHeaderField() async throws {
        let networking = Networking(baseURL: baseURL)
        await networking.setHeaderFields(["HeaderKey": "HeaderValue"])
        let result: Result<JSONResponse, NetworkingError> = await networking.post("/post")
        switch result {
        case .success(let response):
            let headers = httpbinEchoedMap(response, "headers")
            XCTAssertEqual("HeaderValue", headers["Headerkey"])
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }

    func testClearCacheOnlyRemovesTheNetworkingFolder() async throws {
        let cachesRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let networkingFolder = cachesRoot.appendingPathComponent(URL(string: Networking.domain)!.absoluteString)

        let networking = Networking(baseURL: baseURL)
        let _: Result<Image, NetworkingError> = await networking.downloadImage("/image/png")
        let image = Image.find(named: "sample.jpg", inBundle: .module)
        let data = image.jpgData()
        let unrelatedCachedFile = cachesRoot.appendingPathComponent("sample.jpg")
        ((try data?.write(to: unrelatedCachedFile)) as ()??)

        XCTAssertTrue(FileManager.default.exists(at: cachesRoot))
        XCTAssertTrue(FileManager.default.exists(at: networkingFolder))
        XCTAssertTrue(FileManager.default.exists(at: unrelatedCachedFile))

        try await networking.clearCache()

        XCTAssertTrue(FileManager.default.exists(at: cachesRoot))
        XCTAssertFalse(FileManager.default.exists(at: networkingFolder))
        XCTAssertTrue(FileManager.default.exists(at: unrelatedCachedFile))
    }
}
