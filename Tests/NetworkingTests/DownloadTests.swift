import Foundation
import XCTest
@testable import Networking

class DownloadTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testImageDownload() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        try Helper.removeFileIfNeeded(networking, path: path)

        let result = try await networking.downloadImage(path)
        switch result {
        case let .success(response):
            let pigImage = Image.find(named: "pig.png", inBundle: .module)
            let pigImageData = pigImage.pngData()
            let imageData = response.image.pngData()
            XCTAssertEqual(pigImageData, imageData)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    // Find a new source for this test
    /*
    func testImageDownloadWithWeirdCharacters() {
        let networking = Networking(baseURL: "https://rescuejuice.com")
        let path = "/wp-content/uploads/2015/11/døgnvillburgere.jpg"

        try! Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { result in
            switch result {
            case let .success(response):
                let pigImage = Image.find(named: "døgnvillburgere.jpg", inBundle: .module)
                let pigImageData = pigImage.pngData()
                let imageData = response.image.pngData()
                XCTAssertEqual(pigImageData, imageData)
            case let .failure(response):
                XCTFail(response.error.localizedDescription)
            }
        }
    }
    */

    func testDownloadedImageInFile() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        try Helper.removeFileIfNeeded(networking, path: path)

        _ = try await networking.downloadImage(path)
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

        _ = try await networking.downloadImage(path, cacheName: cacheName)
        let destinationURL = try networking.destinationURL(for: path, cacheName: cacheName)
        XCTAssertTrue(FileManager.default.exists(at: destinationURL))
        let data = FileManager.default.contents(atPath: destinationURL.path)
        XCTAssertEqual(data?.count, 8090)
    }

    func testDownloadedImageInCache() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        try Helper.removeFileIfNeeded(networking, path: path)

        let result = try await networking.downloadImage(path)
        switch result {
        case .success:
            let destinationURL = try networking.destinationURL(for: path)
            let absoluteString = destinationURL.absoluteString
            guard let image = networking.cache.object(forKey: absoluteString as AnyObject) as? Image else { XCTFail(); return }
            let pigImage = Image.find(named: "pig.png", inBundle: .module)
            let pigImageData = pigImage.pngData()
            let imageData = image.pngData()
            XCTAssertEqual(pigImageData, imageData)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testDownloadedImageInCacheUsingCustomName() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "png/png"

        try Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)

        let result = try await networking.downloadImage(path, cacheName: cacheName)
        switch result {
        case .success:
            let destinationURL = try networking.destinationURL(for: path, cacheName: cacheName)
            let absoluteString = destinationURL.absoluteString
            guard let image = networking.cache.object(forKey: absoluteString as AnyObject) as? Image else { XCTFail(); return }
            let pigImage = Image.find(named: "pig.png", inBundle: .module)
            let pigImageData = pigImage.pngData()
            let imageData = image.pngData()
            XCTAssertEqual(pigImageData, imageData)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    // Disabled since I don't find a reliable wait to test cancellations
    /*
    func testCancelImageDownload() {
        let expectation = self.expectation(description: "testCancelImageDownload")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        let path = "/image/png"

        try! Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(response):
                XCTAssertEqual(response.error.code, URLError.cancelled.rawValue)
                expectation.fulfill()
            }
        }

        networking.cancelImageDownload("/image/png")

        waitForExpectations(timeout: 15.0, handler: nil)
    }*/

    // Test `imageFromCache` using path, expecting image from Cache
    func testImageFromCacheForPathInCache() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        try Networking.deleteCachedFiles()
        let result = try await networking.downloadImage(path)
        switch result {
        case .success:
            let image = try networking.imageFromCache(path)
            let pigImage = Image.find(named: "pig.png", inBundle: .module)
            let pigImageData = pigImage.pngData()
            let imageData = image?.pngData()
            XCTAssertEqual(pigImageData, imageData)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    // Test `imageFromCache` using cacheName instead of path, expecting image from Cache
    func testImageFromCacheForCustomCacheNameInCache() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "hello"
        try Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)
        _ = try await networking.downloadImage(path, cacheName: cacheName)
        let image = try networking.imageFromCache(path, cacheName: cacheName)
        let pigImage = Image.find(named: "pig.png", inBundle: .module)
        let pigImageData = pigImage.pngData()
        let imageData = image?.pngData()
        XCTAssertEqual(pigImageData, imageData)
    }

    // Test `imageFromCache` using path, expecting image from file
    func testImageFromCacheForPathInFile() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, cache: cache)
        let path = "/image/png"
        try Helper.removeFileIfNeeded(networking, path: path)
        let result = try await networking.downloadImage(path)
        switch result {
        case .success:
            let destinationURL = try networking.destinationURL(for: path)
            let absoluteString = destinationURL.absoluteString
            cache.removeObject(forKey: absoluteString as AnyObject)
            guard let image = try networking.imageFromCache(path) else { XCTFail(); return }
            let pigImage = Image.find(named: "pig.png", inBundle: .module)
            let pigImageData = pigImage.pngData()
            let imageData = image.pngData()
            XCTAssertEqual(pigImageData, imageData)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    // Test `imageFromCache` using cacheName instead of path, expecting image from file
    func testImageFromCacheForCustomCacheNameInFile() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, cache: cache)
        let path = "/image/png"
        let cacheName = "hello"
        try Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)
        let result = try await networking.downloadImage(path, cacheName: cacheName)
        switch result {
        case .success:
            let destinationURL = try networking.destinationURL(for: path, cacheName: cacheName)
            let absoluteString = destinationURL.absoluteString
            cache.removeObject(forKey: absoluteString as AnyObject)
            guard let image = try networking.imageFromCache(path, cacheName: cacheName) else { XCTFail(); return }
            let pigImage = Image.find(named: "pig.png", inBundle: .module)
            let pigImageData = pigImage.pngData()
            let imageData = image.pngData()
            XCTAssertEqual(pigImageData, imageData)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    // Test `imageFromCache` using path, but then clearing cache, and removing files, expecting nil
    func testImageFromCacheNilImage() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, cache: cache)
        let path = "/image/png"
        try Helper.removeFileIfNeeded(networking, path: path)
        let result = try await networking.downloadImage(path)
        switch result {
        case .success:
            let destinationURL = try networking.destinationURL(for: path)
            let absoluteString = destinationURL.absoluteString
            cache.removeObject(forKey: absoluteString as AnyObject)
            try! Helper.removeFileIfNeeded(networking, path: path)
            let image = try networking.imageFromCache(path)
            XCTAssertNil(image)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testDownloadData() async throws {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        try Helper.removeFileIfNeeded(networking, path: path)
        let result = try await networking.downloadData(path)
        switch result {
        case let .success(response):
            XCTAssertEqual(response.data.count, 8090)
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }

    func testDataFromCache() async throws {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: "http://via.placeholder.com", cache: cache)
        let path = "/350x150"

        let result = try await networking.downloadData(path)
        switch result {
        case let .success(response):
            if let cacheData = try networking.dataFromCache(path) {
                XCTAssert(response.data == cacheData)
            } else {
                XCTFail()
            }
        case let .failure(response):
            XCTFail(response.error.localizedDescription)
        }
    }
}
