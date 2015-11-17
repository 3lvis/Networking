import Foundation
import XCTest

class ImageTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func removeFileIfNeeded(networking: Networking, path: String) {
        let destinationURL = networking.destinationURL(path)
        if NSFileManager().fileExistsAtPath(destinationURL.path!) {
            try! NSFileManager().removeItemAtPath(destinationURL.path!)
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

    func testImageDownloadCache() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        self.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, error in
            let destinationURL = networking.destinationURL(path)
            XCTAssertTrue(NSFileManager().fileExistsAtPath(destinationURL.path!))
        }
    }

    func testCancelImageDownload() {
        let expectation = expectationWithDescription("testCancelImageDownload")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        let path = "/image/png"

        self.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { image, error in
            print("image: \(image)")
            print("error: \(error)")
            let canceledCode = error?.code == -999
            XCTAssertTrue(canceledCode)

            expectation.fulfill()
        }

        networking.cancelImageDownload("/image/png")

        waitForExpectationsWithTimeout(3.0, handler: nil)
    }

    func testStubImageDownload() {
        let networking = Networking(baseURL: baseURL)
        let pigImage = UIImage(named: "pig.png", inBundle: NSBundle(forClass: ImageTests.self), compatibleWithTraitCollection: nil)!
        networking.stubImageDownload("/image/png", image: pigImage)
        networking.downloadImage("/image/png") { image, error in
            XCTAssertNotNil(image)
            let pigImageData = UIImagePNGRepresentation(pigImage)
            let imageData = UIImagePNGRepresentation(image!)
            XCTAssertEqual(pigImageData, imageData)
        }
    }
    #endif
}
