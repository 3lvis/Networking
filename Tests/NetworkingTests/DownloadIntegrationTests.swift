import Foundation
import XCTest
@testable import Networking

// @MainActor so the local `NSCache` (non-Sendable) used across the `downloadImage` await stays on
// one actor and doesn't trip strict-concurrency "sending" checks.
@MainActor
class DownloadIntegrationTests: XCTestCase {
    let baseURL = TestConfig.httpbinBaseURL

    func testImageDownload() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        try Helper.removeFileIfNeeded(networking, path: path)

        let result: Result<Image, NetworkingError> = await networking.downloadImage(path)
        switch result {
        case let .success(image):
            let pigImage = Image.find(named: "pig.png", inBundle: .module)
            XCTAssertEqual(pigImage.pngData(), image.pngData())
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    // The envelope form surfaces the status code and headers alongside the image.
    func testImageDownloadResponseEnvelope() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        try Helper.removeFileIfNeeded(networking, path: path)

        let result: Result<ImageResponse, NetworkingError> = await networking.downloadImage(path)
        switch result {
        case let .success(response):
            XCTAssertEqual(response.statusCode, 200)
            let pigImage = Image.find(named: "pig.png", inBundle: .module)
            XCTAssertEqual(pigImage.pngData(), response.image.pngData())
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testDownloadedImageInFile() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        try Helper.removeFileIfNeeded(networking, path: path)

        let _: Result<Image, NetworkingError> = await networking.downloadImage(path)
        let destinationURL = try networking.destinationURL(for: path)
        XCTAssertTrue(FileManager.default.exists(at: destinationURL))
        let data = FileManager.default.contents(atPath: destinationURL.path)
        XCTAssertEqual(data?.count, 8090)
    }

    func testDownloadedImageInFileUsingCustomName() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "png/png"

        try Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)

        let _: Result<Image, NetworkingError> = await networking.downloadImage(path, cacheName: cacheName)
        let destinationURL = try networking.destinationURL(for: path, cacheName: cacheName)
        XCTAssertTrue(FileManager.default.exists(at: destinationURL))
        let data = FileManager.default.contents(atPath: destinationURL.path)
        XCTAssertEqual(data?.count, 8090)
    }

    func testDownloadedImageInCache() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        try Helper.removeFileIfNeeded(networking, path: path)

        let result: Result<Image, NetworkingError> = await networking.downloadImage(path)
        switch result {
        case .success:
            let destinationURL = try networking.destinationURL(for: path)
            let absoluteString = destinationURL.absoluteString
            guard let image = networking.cache.object(forKey: absoluteString as AnyObject) as? Image else { XCTFail(); return }
            let pigImage = Image.find(named: "pig.png", inBundle: .module)
            XCTAssertEqual(pigImage.pngData(), image.pngData())
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testDownloadedImageInCacheUsingCustomName() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "png/png"

        try Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)

        let result: Result<Image, NetworkingError> = await networking.downloadImage(path, cacheName: cacheName)
        switch result {
        case .success:
            let destinationURL = try networking.destinationURL(for: path, cacheName: cacheName)
            let absoluteString = destinationURL.absoluteString
            guard let image = networking.cache.object(forKey: absoluteString as AnyObject) as? Image else { XCTFail(); return }
            let pigImage = Image.find(named: "pig.png", inBundle: .module)
            XCTAssertEqual(pigImage.pngData(), image.pngData())
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    // Test `imageFromCache` using path, expecting image from Cache
    func testImageFromCacheForPathInCache() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        try Networking.deleteCachedFiles()
        let result: Result<Image, NetworkingError> = await networking.downloadImage(path)
        switch result {
        case .success:
            let image = try networking.imageFromCache(path)
            let pigImage = Image.find(named: "pig.png", inBundle: .module)
            XCTAssertEqual(pigImage.pngData(), image?.pngData())
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    // Test `imageFromCache` using cacheName instead of path, expecting image from Cache
    func testImageFromCacheForCustomCacheNameInCache() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "hello"
        try Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)
        let _: Result<Image, NetworkingError> = await networking.downloadImage(path, cacheName: cacheName)
        let image = try networking.imageFromCache(path, cacheName: cacheName)
        let pigImage = Image.find(named: "pig.png", inBundle: .module)
        XCTAssertEqual(pigImage.pngData(), image?.pngData())
    }

    // Test `imageFromCache` using path, expecting image from file
    func testImageFromCacheForPathInFile() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        try Helper.removeFileIfNeeded(networking, path: path)
        let result: Result<Image, NetworkingError> = await networking.downloadImage(path)
        switch result {
        case .success:
            let destinationURL = try networking.destinationURL(for: path)
            let absoluteString = destinationURL.absoluteString
            networking.cache.removeObject(forKey: absoluteString as AnyObject)
            guard let image = try networking.imageFromCache(path) else { XCTFail(); return }
            let pigImage = Image.find(named: "pig.png", inBundle: .module)
            XCTAssertEqual(pigImage.pngData(), image.pngData())
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    // Test `imageFromCache` using cacheName instead of path, expecting image from file
    func testImageFromCacheForCustomCacheNameInFile() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "hello"
        try Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)
        let result: Result<Image, NetworkingError> = await networking.downloadImage(path, cacheName: cacheName)
        switch result {
        case .success:
            let destinationURL = try networking.destinationURL(for: path, cacheName: cacheName)
            let absoluteString = destinationURL.absoluteString
            networking.cache.removeObject(forKey: absoluteString as AnyObject)
            guard let image = try networking.imageFromCache(path, cacheName: cacheName) else { XCTFail(); return }
            let pigImage = Image.find(named: "pig.png", inBundle: .module)
            XCTAssertEqual(pigImage.pngData(), image.pngData())
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    // Test `imageFromCache` using path, but then clearing cache, and removing files, expecting nil
    func testImageFromCacheNilImage() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        try Helper.removeFileIfNeeded(networking, path: path)
        let result: Result<Image, NetworkingError> = await networking.downloadImage(path)
        switch result {
        case .success:
            let destinationURL = try networking.destinationURL(for: path)
            let absoluteString = destinationURL.absoluteString
            networking.cache.removeObject(forKey: absoluteString as AnyObject)
            try Helper.removeFileIfNeeded(networking, path: path)
            let image = try networking.imageFromCache(path)
            XCTAssertNil(image)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testDownloadData() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        try Helper.removeFileIfNeeded(networking, path: path)
        let result: Result<Data, NetworkingError> = await networking.downloadData(path)
        switch result {
        case let .success(data):
            XCTAssertEqual(data.count, 8090)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    // The envelope form surfaces the status code and headers alongside the data.
    func testDownloadDataResponseEnvelope() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        try Helper.removeFileIfNeeded(networking, path: path)
        let result: Result<DataResponse, NetworkingError> = await networking.downloadData(path)
        switch result {
        case let .success(response):
            XCTAssertEqual(response.statusCode, 200)
            XCTAssertEqual(response.data.count, 8090)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }

    func testDataFromCache() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        try Helper.removeFileIfNeeded(networking, path: path)

        let result: Result<Data, NetworkingError> = await networking.downloadData(path)
        switch result {
        case let .success(data):
            if let cacheData = try networking.dataFromCache(path) {
                XCTAssert(data == cacheData)
            } else {
                XCTFail()
            }
        case let .failure(error):
            XCTFail(error.localizedDescription)
        }
    }
}
