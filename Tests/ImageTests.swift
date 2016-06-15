import Foundation
import XCTest

class ImageTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func removeFileIfNeeded(_ networking: Networking, path: String, cacheName: String? = nil) {
        let destinationURL = networking.destinationURL(path, cacheName: cacheName)
        if FileManager.default().fileExistsAtURL(destinationURL) {
            FileManager.default().removeFileAtURL(destinationURL)
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
            networking.imageFromCache(path) { image in
                synchronous = true
                let pigImage = UIImage(named: "pig.png", in: Bundle(for: ImageTests.self), compatibleWith: nil)!
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
            networking.imageFromCache(path, cacheName: cacheName) { image in
                synchronous = true
                let pigImage = UIImage(named: "pig.png", in: Bundle(for: ImageTests.self), compatibleWith: nil)!
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
        let cache: Cache<AnyObject, AnyObject> = Cache()
        let networking = Networking(baseURL: baseURL, cache: cache)
        let path = "/image/png"
        self.removeFileIfNeeded(networking, path: path)
        networking.downloadImage(path) { image, error in
            let destinationURL = networking.destinationURL(path)
            cache.removeObject(forKey: destinationURL.absoluteString!)
            networking.imageFromCache(path) { image in
                synchronous = true
                let pigImage = UIImage(named: "pig.png", in: Bundle(for: ImageTests.self), compatibleWith: nil)!
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
        let cache: Cache<AnyObject, AnyObject> = Cache()
        let networking = Networking(baseURL: baseURL, cache: cache)
        let path = "/image/png"
        let cacheName = "hello"
        self.removeFileIfNeeded(networking, path: path, cacheName: cacheName)
        networking.downloadImage(path, cacheName: cacheName) { image, error in
            let destinationURL = networking.destinationURL(path, cacheName: cacheName)
            cache.removeObject(forKey: destinationURL.absoluteString!)
            networking.imageFromCache(path, cacheName: cacheName) { image in
                synchronous = true
                let pigImage = UIImage(named: "pig.png", in: Bundle(for: ImageTests.self), compatibleWith: nil)!
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
        let cache: Cache<AnyObject, AnyObject> = Cache()
        let networking = Networking(baseURL: baseURL, cache: cache)
        let path = "/image/png"
        self.removeFileIfNeeded(networking, path: path)
        networking.downloadImage(path) { image, error in
            let destinationURL = networking.destinationURL(path)
            cache.removeObject(forKey: destinationURL.absoluteString!)
            self.removeFileIfNeeded(networking, path: path)
            networking.imageFromCache(path) { image in
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
            let pigImage = UIImage(named: "pig.png", in: Bundle(for: ImageTests.self), compatibleWith: nil)!
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
            let pigImage = UIImage(named: "døgnvillburgere.jpg", in: Bundle(for: ImageTests.self), compatibleWith: nil)!
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
            XCTAssertTrue(FileManager.default().fileExistsAtURL(destinationURL))
            XCTAssertNotNil(FileManager.default().contents(atPath: destinationURL.path!))
        }
    }

    func testDownloadedImageInFileUsingCustomName() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "png/png"

        self.removeFileIfNeeded(networking, path: path, cacheName: cacheName)

        networking.downloadImage(path, cacheName: cacheName) { image, error in
            let destinationURL = networking.destinationURL(path, cacheName: cacheName)
            XCTAssertTrue(FileManager.default().fileExistsAtURL(destinationURL))
            XCTAssertNotNil(FileManager.default().contents(atPath: destinationURL.path!))
        }
    }
    func testDownloadedImageInCache() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        self.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, error in
            let destinationURL = networking.destinationURL(path)
            XCTAssertNotNil(networking.cache.object(forKey: destinationURL.absoluteString!))
        }
    }

    func testDownloadedImageInCacheUsingCustomName() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "png/png"

        self.removeFileIfNeeded(networking, path: path, cacheName: cacheName)

        networking.downloadImage(path, cacheName: cacheName) { image, error in
            let destinationURL = networking.destinationURL(path, cacheName: cacheName)
            XCTAssertNotNil(networking.cache.object(forKey: destinationURL.absoluteString!))
        }
    }

    func testCancelImageDownload() {
        let expectation = self.expectation(withDescription: "testCancelImageDownload")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        let path = "/image/png"

        self.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, error in
            let canceledCode = error?.code == -999
            XCTAssertTrue(canceledCode)

            expectation.fulfill()
        }

        networking.cancelImageDownload("/image/png")

        waitForExpectations(withTimeout: 15.0, handler: nil)
    }

    func testFakeImageDownload() {
        let networking = Networking(baseURL: baseURL)
        let pigImage = UIImage(named: "pig.png", in: Bundle(for: ImageTests.self), compatibleWith: nil)!
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
