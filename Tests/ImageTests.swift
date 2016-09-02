import Foundation
import XCTest

class ImageTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testImageDownloadSynchronous() {
        var synchronous = false

        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, error in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testDownloadImageReturnBlockInMainThread() {
        let expectation = expectationWithDescription("testDownloadImageReturnBlockInMainThread")
        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.downloadImage("/image/png") { JSON, error in
            XCTAssertTrue(NSThread.isMainThread())
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(15.0, handler: nil)
    }

    func testImageDownload() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, error in
            let pigImage = NetworkingImage.find(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self))
            let pigImageData = pigImage.pngData()
            let imageData = image?.pngData()
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    func testImageDownloadWithWeirdCharacters() {
        let networking = Networking(baseURL: "https://rescuejuice.com")
        let path = "/wp-content/uploads/2015/11/døgnvillburgere.jpg"

        Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, error in
            let pigImage = NetworkingImage.find(named: "døgnvillburgere.jpg", inBundle: NSBundle(forClass: ImageTests.self))
            let pigImageData = pigImage.pngData()
            let imageData = image?.pngData()
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    func testDownloadedImageInFile() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, error in
            guard let destinationURL = try? networking.destinationURL(path) else { XCTFail(); return }
            XCTAssertTrue(NSFileManager.defaultManager().fileExistsAtURL(destinationURL))
            guard let path = destinationURL.path else { XCTFail(); return }
            let data = NSFileManager.defaultManager().contentsAtPath(path)
            XCTAssertEqual(data?.length, 8090)
        }
    }

    func testDownloadedImageInFileUsingCustomName() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "png/png"

        Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)

        networking.downloadImage(path, cacheName: cacheName) { image, error in
            guard let destinationURL = try? networking.destinationURL(path, cacheName: cacheName) else { XCTFail(); return }
            XCTAssertTrue(NSFileManager.defaultManager().fileExistsAtURL(destinationURL))
            guard let path = destinationURL.path else { XCTFail(); return }
            let data = NSFileManager.defaultManager().contentsAtPath(path)
            XCTAssertEqual(data?.length, 8090)
        }
    }

    func testDownloadedImageInCache() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, error in
            guard let destinationURL = try? networking.destinationURL(path) else { XCTFail(); return }
            #if swift(>=2.3)
                let image = networking.cache.objectForKey(destinationURL.absoluteString!) as? NetworkingImage
            #else
                let image = networking.cache.objectForKey(destinationURL.absoluteString) as? NetworkingImage
            #endif
            let pigImage = NetworkingImage.find(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self))
            let pigImageData = pigImage.pngData()
            let imageData = image?.pngData()
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    func testDownloadedImageInCacheUsingCustomName() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "png/png"

        Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)

        networking.downloadImage(path, cacheName: cacheName) { image, error in
            guard let destinationURL = try? networking.destinationURL(path, cacheName: cacheName) else { XCTFail(); return }
            #if swift(>=2.3)
                let image = networking.cache.objectForKey(destinationURL.absoluteString!) as? NetworkingImage
            #else
                let image = networking.cache.objectForKey(destinationURL.absoluteString) as? NetworkingImage
            #endif
            let pigImage = NetworkingImage.find(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self))
            let pigImageData = pigImage.pngData()
            let imageData = image?.pngData()
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    func testCancelImageDownload() {
        let expectation = expectationWithDescription("testCancelImageDownload")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        let path = "/image/png"

        Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, error in
            XCTAssertEqual(error?.code, -999)
            expectation.fulfill()
        }

        networking.cancelImageDownload("/image/png")

        waitForExpectationsWithTimeout(15.0, handler: nil)
    }

    func testFakeImageDownload() {
        let networking = Networking(baseURL: baseURL)
        let pigImage = NetworkingImage.find(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self))
        networking.fakeImageDownload("/image/png", image: pigImage)
        networking.downloadImage("/image/png") { image, error in
            let pigImageData = pigImage.pngData()
            let imageData = image?.pngData()
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    func testFakeImageDownloadWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)
        networking.fakeImageDownload("/image/png", image: nil, statusCode: 401)
        networking.downloadImage("/image/png") { image, error in
            XCTAssertEqual(error?.code, 401)
        }
    }

    func testImageFromCacheReturnBlockInMainThread() {
        let expectation = expectationWithDescription("testImageFromCacheReturnBlockInMainThread")
        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.imageFromCache("/image/png") { image in
            XCTAssertTrue(NSThread.isMainThread())
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(15.0, handler: nil)
    }

    // Test `imageFromCache` using path, expecting image from NSCache
    func testImageFromCacheForPathInCache() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        Helper.removeFileIfNeeded(networking, path: path)
        networking.downloadImage(path) { image, error in
            networking.imageFromCache(path) { image in
                synchronous = true
                let pigImage = NetworkingImage.find(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self))
                let pigImageData = pigImage.pngData()
                let imageData = image?.pngData()
                XCTAssertEqual(pigImageData, imageData)
            }
        }
        XCTAssertTrue(synchronous)
    }

    // Test `imageFromCache` using cacheName instead of path, expecting image from NSCache
    func testImageFromCacheForCustomCacheNameInCache() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "hello"
        Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)
        networking.downloadImage(path, cacheName: cacheName) { _, _ in
            networking.imageFromCache(path, cacheName: cacheName) { image in
                synchronous = true
                let pigImage = NetworkingImage.find(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self))
                let pigImageData = pigImage.pngData()
                let imageData = image?.pngData()
                XCTAssertEqual(pigImageData, imageData)
            }
        }
        XCTAssertTrue(synchronous)
    }

    // Test `imageFromCache` using path, expecting image from file
    func testImageFromCacheForPathInFile() {
        var synchronous = false
        let cache = NSCache()
        let networking = Networking(baseURL: baseURL, cache: cache)
        let path = "/image/png"
        Helper.removeFileIfNeeded(networking, path: path)
        networking.downloadImage(path) { image, error in
            guard let destinationURL = try? networking.destinationURL(path) else { XCTFail(); return }
            #if swift(>=2.3)
                cache.removeObjectForKey(destinationURL.absoluteString!)
            #else
                cache.removeObjectForKey(destinationURL.absoluteString)
            #endif
            networking.imageFromCache(path) { image in
                synchronous = true
                let pigImage = NetworkingImage.find(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self))
                let pigImageData = pigImage.pngData()
                let imageData = image?.pngData()
                XCTAssertEqual(pigImageData, imageData)
            }
        }
        XCTAssertTrue(synchronous)
    }

    // Test `imageFromCache` using cacheName instead of path, expecting image from file
    func testImageFromCacheForCustomCacheNameInFile() {
        var synchronous = false
        let cache = NSCache()
        let networking = Networking(baseURL: baseURL, cache: cache)
        let path = "/image/png"
        let cacheName = "hello"
        Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)
        networking.downloadImage(path, cacheName: cacheName) { image, error in
            guard let destinationURL = try? networking.destinationURL(path, cacheName: cacheName) else { XCTFail(); return }
            #if swift(>=2.3)
                cache.removeObjectForKey(destinationURL.absoluteString!)
            #else
                cache.removeObjectForKey(destinationURL.absoluteString)
            #endif
            networking.imageFromCache(path, cacheName: cacheName) { image in
                synchronous = true
                let pigImage = NetworkingImage.find(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self))
                let pigImageData = pigImage.pngData()
                let imageData = image?.pngData()
                XCTAssertEqual(pigImageData, imageData)
            }
        }
        XCTAssertTrue(synchronous)
    }

    // Test `imageFromCache` using path, but then clearing cache, and removing files, expecting nil
    func testImageFromCacheNilImage() {
        var synchronous = false
        let cache = NSCache()
        let networking = Networking(baseURL: baseURL, cache: cache)
        let path = "/image/png"
        Helper.removeFileIfNeeded(networking, path: path)
        networking.downloadImage(path) { image, error in
            guard let destinationURL = try? networking.destinationURL(path) else { XCTFail(); return }
            #if swift(>=2.3)
                cache.removeObjectForKey(destinationURL.absoluteString!)
            #else
                cache.removeObjectForKey(destinationURL.absoluteString)
            #endif
            Helper.removeFileIfNeeded(networking, path: path)
            networking.imageFromCache(path) { image in
                synchronous = true
                XCTAssertNil(image)
            }
        }
        XCTAssertTrue(synchronous)
    }
}
