import Foundation
import XCTest

class DownloadTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testImageDownloadSynchronous() {
        var synchronous = false

        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        try! Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { _ in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testDownloadImageReturnBlockInMainThread() {
        let expectation = self.expectation(description: "testDownloadImageReturnBlockInMainThread")
        let networking = Networking(baseURL: baseURL)
        networking.isSynchronous = true
        networking.downloadImage("/image/png") { _ in
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testImageDownload() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        try! Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { result in
            switch result {
            case .success(let response):
                let pigImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: DownloadTests.self))
                let pigImageData = pigImage.pngData()
                let imageData = response.image.pngData()
                XCTAssertEqual(pigImageData, imageData)
            case .failure:
                XCTFail()
            }
        }
    }

    func testImageDownloadWithWeirdCharacters() {
        let networking = Networking(baseURL: "https://rescuejuice.com")
        let path = "/wp-content/uploads/2015/11/døgnvillburgere.jpg"

        try! Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { result in
            switch result {
            case .success(let response):
                let pigImage = NetworkingImage.find(named: "døgnvillburgere.jpg", inBundle: Bundle(for: DownloadTests.self))
                let pigImageData = pigImage.pngData()
                let imageData = response.image.pngData()
                XCTAssertEqual(pigImageData, imageData)
            case .failure:
                XCTFail()
            }
        }
    }

    func testDownloadedImageInFile() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"

        try! Helper.removeFileIfNeeded(networking, path: path)

        networking.downloadImage(path) { _ in
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

        networking.downloadImage(path, cacheName: cacheName) { _ in
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

        networking.downloadImage(path) { result in
            switch result {
            case .success:
                guard let destinationURL = try? networking.destinationURL(for: path) else { XCTFail(); return }
                let absoluteString = destinationURL.absoluteString
                guard let image = networking.cache.object(forKey: absoluteString as AnyObject) as? NetworkingImage else { XCTFail(); return }
                let pigImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: DownloadTests.self))
                let pigImageData = pigImage.pngData()
                let imageData = image.pngData()
                XCTAssertEqual(pigImageData, imageData)
            case .failure:
                XCTFail()
            }
        }
    }

    func testDownloadedImageInCacheUsingCustomName() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "png/png"

        try! Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)

        networking.downloadImage(path, cacheName: cacheName) { result in
            switch result {
            case .success:
                guard let destinationURL = try? networking.destinationURL(for: path, cacheName: cacheName) else { XCTFail(); return }
                let absoluteString = destinationURL.absoluteString
                guard let image = networking.cache.object(forKey: absoluteString as AnyObject) as? NetworkingImage else { XCTFail(); return }
                let pigImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: DownloadTests.self))
                let pigImageData = pigImage.pngData()
                let imageData = image.pngData()
                XCTAssertEqual(pigImageData, imageData)
            case .failure:
                XCTFail()
            }
        }
    }

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
            case .failure(let response):
                XCTAssertEqual(response.error.code, URLError.cancelled.rawValue)
                expectation.fulfill()
            }
        }

        networking.cancelImageDownload("/image/png")

        waitForExpectations(timeout: 15.0, handler: nil)
    }

    func testFakeImageDownload() {
        let networking = Networking(baseURL: baseURL)
        let pigImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: DownloadTests.self))
        networking.fakeImageDownload("/image/png", image: pigImage)
        networking.downloadImage("/image/png") { result in
            switch result {
            case .success(let response):
                let pigImageData = pigImage.pngData()
                let imageData = response.image.pngData()
                XCTAssertEqual(pigImageData, imageData)
            case .failure:
                XCTFail()
            }
        }
    }

    func testFakeImageDownloadWithInvalidStatusCode() {
        let networking = Networking(baseURL: baseURL)
        networking.fakeImageDownload("/image/png", image: nil, statusCode: 401)
        networking.downloadImage("/image/png") { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(let response):
                XCTAssertEqual(response.error.code, 401)
            }
        }
    }

    // Test `imageFromCache` using path, expecting image from Cache
    func testImageFromCacheForPathInCache() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        Networking.deleteCachedFiles()
        networking.downloadImage(path) { result in
            switch result {
            case .success:
                guard let image = networking.imageFromCache(path) else { XCTFail(); return }
                let pigImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: DownloadTests.self))
                let pigImageData = pigImage.pngData()
                let imageData = image.pngData()
                XCTAssertEqual(pigImageData, imageData)
            case .failure:
                XCTFail()
            }
        }
    }

    // Test `imageFromCache` using cacheName instead of path, expecting image from Cache
    func testImageFromCacheForCustomCacheNameInCache() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let cacheName = "hello"
        try! Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)
        networking.downloadImage(path, cacheName: cacheName) { _ in
            let image = networking.imageFromCache(path, cacheName: cacheName)
            let pigImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: DownloadTests.self))
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
        networking.downloadImage(path) { result in
            switch result {
            case .success:
                guard let destinationURL = try? networking.destinationURL(for: path) else { XCTFail(); return }
                let absoluteString = destinationURL.absoluteString
                cache.removeObject(forKey: absoluteString as AnyObject)
                guard let image = networking.imageFromCache(path) else { XCTFail(); return }
                let pigImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: DownloadTests.self))
                let pigImageData = pigImage.pngData()
                let imageData = image.pngData()
                XCTAssertEqual(pigImageData, imageData)
            case .failure:
                XCTFail()
            }
        }
    }

    // Test `imageFromCache` using cacheName instead of path, expecting image from file
    func testImageFromCacheForCustomCacheNameInFile() {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, cache: cache)
        let path = "/image/png"
        let cacheName = "hello"
        try! Helper.removeFileIfNeeded(networking, path: path, cacheName: cacheName)
        networking.downloadImage(path, cacheName: cacheName) { result in
            switch result {
            case .success:
                guard let destinationURL = try? networking.destinationURL(for: path, cacheName: cacheName) else { XCTFail(); return }
                let absoluteString = destinationURL.absoluteString
                cache.removeObject(forKey: absoluteString as AnyObject)
                guard let image = networking.imageFromCache(path) else { XCTFail(); return }
                let pigImage = NetworkingImage.find(named: "pig.png", inBundle: Bundle(for: DownloadTests.self))
                let pigImageData = pigImage.pngData()
                let imageData = image.pngData()
                XCTAssertEqual(pigImageData, imageData)
            case .failure:
                XCTFail()
            }
        }
    }

    // Test `imageFromCache` using path, but then clearing cache, and removing files, expecting nil
    func testImageFromCacheNilImage() {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: baseURL, cache: cache)
        let path = "/image/png"
        try! Helper.removeFileIfNeeded(networking, path: path)
        networking.downloadImage(path) { result in
            switch result {
            case .success:
                guard let destinationURL = try? networking.destinationURL(for: path) else { XCTFail(); return }
                let absoluteString = destinationURL.absoluteString
                cache.removeObject(forKey: absoluteString as AnyObject)
                try! Helper.removeFileIfNeeded(networking, path: path)
                let image = networking.imageFromCache(path)
                XCTAssertNil(image)
            case .failure:
                XCTFail()
            }
        }
    }

    func testDownloadData() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        try! Helper.removeFileIfNeeded(networking, path: path)
        networking.downloadData(for: path) { result in
            switch result {
            case .success(let response):
                synchronous = true
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(response.data.count, 8090)
            case .failure:
                XCTFail()
            }
        }
        XCTAssertTrue(synchronous)
    }

    func testDataFromCache() {
        let cache = NSCache<AnyObject, AnyObject>()
        let networking = Networking(baseURL: "http://store.storeimages.cdn-apple.com", cache: cache)
        let path = "/4973/as-images.apple.com/is/image/AppleInc/aos/published/images/i/pa/ipad/pro/ipad-pro-201603-gallery3?wid=4000&amp%3Bhei=1536&amp%3Bfmt=jpeg&amp%3Bqlt=95&amp%3Bop_sharpen=0&amp%3BresMode=bicub&amp%3Bop_usm=0.5%2C0.5%2C0%2C0&amp%3BiccEmbed=0&amp%3Blayer=comp&amp%3B.v=Y7wkx0&hei=3072"

        networking.downloadData(for: path) { result in
            switch result {
            case .success(let response):
                let cacheData = networking.dataFromCache(for: path)
                XCTAssert(response.data == cacheData!)
            case .failure:
                XCTFail()
            }
        }
    }

    func testDeleteDownloadedFiles() {
        let networking = Networking(baseURL: baseURL)
        networking.downloadImage("/image/png") { _ in
            #if os(tvOS)
                let directory = FileManager.SearchPathDirectory.cachesDirectory
            #else
                let directory = TestCheck.isTesting ? FileManager.SearchPathDirectory.cachesDirectory : FileManager.SearchPathDirectory.documentDirectory
            #endif
            let cachesURL = FileManager.default.urls(for: directory, in: .userDomainMask).first!
            let folderURL = cachesURL.appendingPathComponent(URL(string: Networking.domain)!.absoluteString)
            XCTAssertTrue(FileManager.default.exists(at: folderURL))
            Networking.deleteCachedFiles()
            XCTAssertFalse(FileManager.default.exists(at: folderURL))
        }
    }
}
