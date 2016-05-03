import Foundation
import XCTest

class ImageTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func removeFileIfNeeded(networking: Networking, path: String, cacheName: String? = nil) {
        let destinationURL = networking.destinationURL(path, cacheName: cacheName)
        if NSFileManager.defaultManager().fileExistsAtURL(destinationURL) {
            NSFileManager.defaultManager().removeFileAtURL(destinationURL)
        }
    }

    #if os(iOS) || os(tvOS) || os(watchOS)
    // Test `imageFromCache` using path, expecting image from NSCache
    func testImageFromCacheForPathInCache() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        self.removeFileIfNeeded(networking, path: path)
        networking.downloadImage(path) { image, error in
            networking.imageFromCache(path) { image, error in
                synchronous = true
                let pigImage = UIImage(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self), compatibleWithTraitCollection: nil)!
                let pigImageData = UIImagePNGRepresentation(pigImage)
                let imageData = UIImagePNGRepresentation(image!)
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
        self.removeFileIfNeeded(networking, path: path, cacheName: cacheName)
        networking.downloadImage(path, cacheName: cacheName) { image, error in
            networking.imageFromCache(path, cacheName: cacheName) { image, error in
                synchronous = true
                let pigImage = UIImage(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self), compatibleWithTraitCollection: nil)!
                let pigImageData = UIImagePNGRepresentation(pigImage)
                let imageData = UIImagePNGRepresentation(image!)
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
        self.removeFileIfNeeded(networking, path: path)
        networking.downloadImage(path) { image, error in
            let destinationURL = networking.destinationURL(path)
            cache.removeObjectForKey(destinationURL.absoluteString)
            networking.imageFromCache(path) { image, error in
                synchronous = true
                let pigImage = UIImage(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self), compatibleWithTraitCollection: nil)!
                let pigImageData = UIImagePNGRepresentation(pigImage)
                let imageData = UIImagePNGRepresentation(image!)
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
        self.removeFileIfNeeded(networking, path: path, cacheName: cacheName)
        networking.downloadImage(path, cacheName: cacheName) { image, error in
            let destinationURL = networking.destinationURL(path, cacheName: cacheName)
            cache.removeObjectForKey(destinationURL.absoluteString)
            networking.imageFromCache(path, cacheName: cacheName) { image, error in
                synchronous = true
                let pigImage = UIImage(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self), compatibleWithTraitCollection: nil)!
                let pigImageData = UIImagePNGRepresentation(pigImage)
                let imageData = UIImagePNGRepresentation(image!)
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
        self.removeFileIfNeeded(networking, path: path)
        networking.downloadImage(path) { image, error in
            let destinationURL = networking.destinationURL(path)
            cache.removeObjectForKey(destinationURL.absoluteString)
            self.removeFileIfNeeded(networking, path: path)
            networking.imageFromCache(path) { image, error in
                synchronous = true
                XCTAssertNil(image)
            }
        }
        XCTAssertTrue(synchronous)
    }

    func testImageDownloadSynchronous() {
        var synchronous = false

        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        self.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, error in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testImageDownload() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        self.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, error in
            XCTAssertNotNil(image)
            let pigImage = UIImage(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self), compatibleWithTraitCollection: nil)!
            let pigImageData = UIImagePNGRepresentation(pigImage)
            let imageData = UIImagePNGRepresentation(image!)
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    func testImageDownloadWithWeirdCharacters() {
        let networking = Networking(baseURL: "https://rescuejuice.com")
        let path = "/wp-content/uploads/2015/11/døgnvillburgere.jpg"

        self.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, error in
            XCTAssertNotNil(image)
            let pigImage = UIImage(named: "døgnvillburgere.jpg", inBundle: NSBundle(forClass: ImageTests.self), compatibleWithTraitCollection: nil)!
            let pigImageData = UIImagePNGRepresentation(pigImage)
            let imageData = UIImagePNGRepresentation(image!)
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    func testDownloadedImageInFile() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        self.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, error in
            let destinationURL = networking.destinationURL(path)
            XCTAssertTrue(NSFileManager.defaultManager().fileExistsAtURL(destinationURL))
            XCTAssertNotNil(NSFileManager.defaultManager().contentsAtPath(destinationURL.path!))
        }
    }

    func testDownloadedImageInFileUsingCustomName() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "png/png"

        self.removeFileIfNeeded(networking, path: path, cacheName: cacheName)

        networking.downloadImage(path, cacheName: cacheName) { image, error in
            let destinationURL = networking.destinationURL(path, cacheName: cacheName)
            XCTAssertTrue(NSFileManager.defaultManager().fileExistsAtURL(destinationURL))
            XCTAssertNotNil(NSFileManager.defaultManager().contentsAtPath(destinationURL.path!))
        }
    }
    func testDownloadedImageInCache() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        self.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, error in
            let destinationURL = networking.destinationURL(path)
            XCTAssertNotNil(networking.cache.objectForKey(destinationURL.absoluteString))
        }
    }

    func testDownloadedImageInCacheUsingCustomName() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "png/png"

        self.removeFileIfNeeded(networking, path: path, cacheName: cacheName)

        networking.downloadImage(path, cacheName: cacheName) { image, error in
            let destinationURL = networking.destinationURL(path, cacheName: cacheName)
            XCTAssertNotNil(networking.cache.objectForKey(destinationURL.absoluteString))
        }
    }

    func testCancelImageDownload() {
        let expectation = expectationWithDescription("testCancelImageDownload")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        let path = "/image/png"

        self.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, error in
            let canceledCode = error?.code == -999
            XCTAssertTrue(canceledCode)

            expectation.fulfill()
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            networking.cancelImageDownload("/image/png")
        }

        waitForExpectationsWithTimeout(15.0, handler: nil)
    }

    func testFakeImageDownload() {
        let networking = Networking(baseURL: baseURL)
        let pigImage = UIImage(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self), compatibleWithTraitCollection: nil)!
        networking.fakeImageDownload("/image/png", image: pigImage)
        networking.downloadImage("/image/png") { image, error in
            XCTAssertNotNil(image)
            let pigImageData = UIImagePNGRepresentation(pigImage)
            let imageData = UIImagePNGRepresentation(image!)
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    func testFakeImageDownloadWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)
        networking.fakeImageDownload("/image/png", image: nil, statusCode: 401)
        networking.downloadImage("/image/png") { image, error in
            XCTAssertEqual(401, error!.code)
        }
    }
    #endif
}
