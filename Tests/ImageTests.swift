import Foundation
import XCTest

class ImageTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testImageDownloadSynchronous() {
        var synchronous = false

        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        try! Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { _, _ in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testDownloadImageReturnBlockInMainThread() {
        let expectation = self.expectation(description: "testDownloadImageReturnBlockInMainThread")
        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        networking.downloadImage("/image/png") { _, _ in
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testImageDownload() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        try! Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, _ in
            let pigImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: ImageTests.self))
            let pigImageData = pigImage.pngData()
            let imageData = image?.pngData()
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    func testImageDownloadWithWeirdCharacters() {
        let networking = Networking(baseURL: "https://rescuejuice.com")
        let path = "/wp-content/uploads/2015/11/døgnvillburgere.jpg"

        try! Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, _ in
            let pigImage = NetworkingImage.find(named: "døgnvillburgere.jpg", inBundle: Bundle(for: ImageTests.self))
            let pigImageData = pigImage.pngData()
            let imageData = image?.pngData()
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    func testDownloadedImageInFile() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        try! Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { _, _ in
            guard let destinationURL = try? networking.destinationURL(for: path) else { XCTFail(); return }
            XCTAssertTrue(FileManager.default.exists(at: destinationURL))
            let path = destinationURL.path
            let data = FileManager.default.contents(atPath: path)
            XCTAssertEqual(data?.count, 8090)
        }
    }

    func testDownloadedImageInFileUsingCustomName() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "png/png"

        try! Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)

        networking.downloadImage(path, cacheName: cacheName) { _, _ in
            guard let destinationURL = try? networking.destinationURL(for: path, cacheName: cacheName) else { XCTFail(); return }
            XCTAssertTrue(FileManager.default.exists(at: destinationURL))
            let path = destinationURL.path
            let data = FileManager.default.contents(atPath: path)
            XCTAssertEqual(data?.count, 8090)
        }
    }

    func testDownloadedImageInCache() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        try! Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, _ in
            guard let destinationURL = try? networking.destinationURL(for: path) else { XCTFail(); return }
            let absoluteString = destinationURL.absoluteString
            let image = networking.cache.object(forKey: absoluteString as AnyObject) as? NetworkingImage
            let pigImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: ImageTests.self))
            let pigImageData = pigImage.pngData()
            let imageData = image?.pngData()
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    func testDownloadedImageInCacheUsingCustomName() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "png/png"

        try! Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)

        networking.downloadImage(path, cacheName: cacheName) { image, _ in
            guard let destinationURL = try? networking.destinationURL(for: path, cacheName: cacheName) else { XCTFail(); return }
            let absoluteString = destinationURL.absoluteString
            let image = networking.cache.object(forKey: absoluteString as AnyObject) as? NetworkingImage
            let pigImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: ImageTests.self))
            let pigImageData = pigImage.pngData()
            let imageData = image?.pngData()
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    func testCancelImageDownload() {
        let expectation = self.expectation(description: "testCancelImageDownload")

        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        let path = "/image/png"

        try! Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { _, error in
            XCTAssertEqual(error?.code, URLError.cancelled.rawValue)
            expectation.fulfill()
        }

        networking.cancelImageDownload("/image/png")

        waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testFakeImageDownload() {
        let networking = Networking(baseURL: baseURL)
        let pigImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: ImageTests.self))
        networking.fakeImageDownload("/image/png", image: pigImage)
        networking.downloadImage("/image/png") { image, _ in
            let pigImageData = pigImage.pngData()
            let imageData = image?.pngData()
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    func testFakeImageDownloadWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)
        networking.fakeImageDownload("/image/png", image: nil, statusCode: 401)
        networking.downloadImage("/image/png") { _, error in
            XCTAssertEqual(error?.code, 401)
        }
    }

    // Test `imageFromCache` using path, expecting image from Cache
    func testImageFromCacheForPathInCache() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        Networking.deleteCachedFiles()
        networking.downloadImage(path) { image, _ in
            let image = networking.imageFromCache(path)
            let pigImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: ImageTests.self))
            let pigImageData = pigImage.pngData()
            let imageData = image?.pngData()
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    // Test `imageFromCache` using cacheName instead of path, expecting image from Cache
    func testImageFromCacheForCustomCacheNameInCache() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "hello"
        try! Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)
        networking.downloadImage(path, cacheName: cacheName) { _, _ in
            let image = networking.imageFromCache(path, cacheName: cacheName)
            let pigImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: ImageTests.self))
            let pigImageData = pigImage.pngData()
            let imageData = image?.pngData()
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    // Test `imageFromCache` using path, expecting image from file
    func testImageFromCacheForPathInFile() {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, cache: cache)
        let path = "/image/png"
        try! Helper.removeFileIfNeeded(networking, path: path)
        networking.downloadImage(path) { image, _ in
            guard let destinationURL = try? networking.destinationURL(for: path) else { XCTFail(); return }
            let absoluteString = destinationURL.absoluteString
            cache.removeObject(forKey: absoluteString as AnyObject)
            let image = networking.imageFromCache(path)
            let pigImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: ImageTests.self))
            let pigImageData = pigImage.pngData()
            let imageData = image?.pngData()
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    // Test `imageFromCache` using cacheName instead of path, expecting image from file
    func testImageFromCacheForCustomCacheNameInFile() {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, cache: cache)
        let path = "/image/png"
        let cacheName = "hello"
        try! Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)
        networking.downloadImage(path, cacheName: cacheName) { image, _ in
            guard let destinationURL = try? networking.destinationURL(for: path, cacheName: cacheName) else { XCTFail(); return }
            let absoluteString = destinationURL.absoluteString
            cache.removeObject(forKey: absoluteString as AnyObject)
            let image = networking.imageFromCache(path, cacheName: cacheName)
            let pigImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: ImageTests.self))
            let pigImageData = pigImage.pngData()
            let imageData = image?.pngData()
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    // Test `imageFromCache` using path, but then clearing cache, and removing files, expecting nil
    func testImageFromCacheNilImage() {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, cache: cache)
        let path = "/image/png"
        try! Helper.removeFileIfNeeded(networking, path: path)
        networking.downloadImage(path) { image, _ in
            guard let destinationURL = try? networking.destinationURL(for: path) else { XCTFail(); return }
            let absoluteString = destinationURL.absoluteString
            cache.removeObject(forKey: absoluteString as AnyObject)
            try! Helper.removeFileIfNeeded(networking, path: path)
            let image = networking.imageFromCache(path)
            XCTAssertNil(image)
        }
    }
}
