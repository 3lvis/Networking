import Foundation
import XCTest
@testable import Networking

class NetworkingIntegrationTests: XCTestCase {
    let baseURL = "http://httpbin.org"

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
            let headers = json["headers"] as? [String: Any]
            XCTAssertEqual("Bearer \(token)", headers?["Authorization"] as? String)
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
            let headers = json["headers"] as? [String: Any]
            XCTAssertEqual("HeaderValue", headers?["Headerkey"] as? String)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    // I don't know how to test cancelling
    /*
    func testCancelAllRequests() async throws {
        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        var cancelledGET = false
        var cancelledPOST = false

        let result = try await networking.oldGet("/get")
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            cancelledGET = response.error.code == URLError.cancelled.rawValue
            XCTAssertTrue(cancelledGET)

            if cancelledGET && cancelledPOST {
                // ?
            }
        }

        networking.oldPost("/post") { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                cancelledPOST = response.error.code == URLError.cancelled.rawValue
                XCTAssertTrue(cancelledPOST)

                if cancelledGET && cancelledPOST {
                    // ?
                }
            }
        }

        await networking.cancelAllRequests()
    }*/

    // I don't know how to test cancelling
    /*
    func testCancelRequestsReturnInMainThread() async throws {
        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        let result = try await networking.oldGet("/get")
        switch result {
        case .success:
            XCTFail()
        case let .failure(response):
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(response.error.code, URLError.cancelled.rawValue)
        }
        await networking.cancelAllRequests()
    }*/

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
