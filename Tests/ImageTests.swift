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
        let cacheName = "png"

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
            XCTAssertNotNil(networking.imageCache.objectForKey(destinationURL.absoluteString))
        }
    }

    func testDownloadedImageInCacheUsingCustomName() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "png"

        self.removeFileIfNeeded(networking, path: path, cacheName: cacheName)

        networking.downloadImage(path, cacheName: cacheName) { image, error in
            let destinationURL = networking.destinationURL(path, cacheName: cacheName)
            XCTAssertNotNil(networking.imageCache.objectForKey(destinationURL.absoluteString))
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

        networking.cancelImageDownload("/image/png")

        waitForExpectationsWithTimeout(3.0, handler: nil)
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
