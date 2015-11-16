import Foundation
import XCTest

class Tests: XCTestCase {
    let baseURL = "http://httpbin.org"
}

// MARK: GET

extension Tests {
    func testSynchronousGET() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.GET("/get", completion: { JSON, error in
            synchronous = true
        })

        XCTAssertTrue(synchronous)
    }

    func testGET() {
        let networking = Networking(baseURL: baseURL)
        networking.GET("/get", completion: { JSON, error in
            let JSON = JSON as! [String : AnyObject]
            let url = JSON["url"] as! String
            XCTAssertEqual(url, "http://httpbin.org/get")
        })
    }

    func testCancelGET() {
        let expectation = expectationWithDescription("testCancelGET")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.GET("/get", completion: { JSON, error in
            let canceledCode = error?.code == -999
            XCTAssertTrue(canceledCode)

            expectation.fulfill()
        })

        networking.cancelGET("/get")

        waitForExpectationsWithTimeout(3.0, handler: nil)
    }

    func testGETWithInvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.GET("/invalidpath", completion: { JSON, error in
            if let JSON: AnyObject = JSON {
                fatalError("JSON not nil: \(JSON)")
            } else {
                XCTAssertNotNil(error)
            }
        })
    }

    func testGETStubs() {
        let networking = Networking(baseURL: baseURL)

        networking.stubGET("/stories", response: ["name" : "Elvis"])

        networking.GET("/stories", completion: { JSON, error in
            let JSON = JSON as! [String : String]
            let value = JSON["name"]
            XCTAssertEqual(value!, "Elvis")
        })
    }

    func testGETStubsUsingFile() {
        let networking = Networking(baseURL: baseURL)

        networking.stubGET("/entries", fileName: "entries.json", bundle: NSBundle(forClass: self.classForKeyedArchiver!))

        networking.GET("/entries", completion: { JSON, error in
            let JSON = JSON as! [[String : AnyObject]]
            let entry = JSON[0]
            let value = entry["title"] as! String
            XCTAssertEqual(value, "Entry 1")
        })
    }
}

// MARK: POST

extension Tests {
    func testSynchronousPOST() {
        var synchronous = false
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post", parameters: nil) { JSON, error in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testPOST() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/post", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            XCTAssertNotNil(JSON!, "JSON not nil")
            XCTAssertNil(error, "Error")
        }
    }

    func testCancelPOST() {
        let expectation = expectationWithDescription("testCancelPOST")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.POST("/post", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            let canceledCode = error?.code == -999
            XCTAssertTrue(canceledCode)

            expectation.fulfill()
        }

        networking.cancelPOST("/post")

        waitForExpectationsWithTimeout(3.0, handler: nil)
    }

    func testPOSTWithIvalidPath() {
        let networking = Networking(baseURL: baseURL)
        networking.POST("/posdddddt", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            XCTAssertNotNil(error)
            XCTAssertNil(JSON)
        }
    }

    func testPOSTStubs() {
        let networking = Networking(baseURL: baseURL)

        networking.stubPOST("/story", response: [["name" : "Elvis"]])

        networking.POST("/story", parameters: ["username":"jameson", "password":"password"]) { JSON, error in
            let JSON = JSON as! [[String : String]]
            let value = JSON[0]["name"]
            XCTAssertEqual(value!, "Elvis")
        }
    }
}

// MARK: Image

extension Tests {
    #if os(iOS) || os(tvOS) || os(watchOS)
    func testImageDownloadSynchronous() {
        var synchronous = false

        let networking = Networking(baseURL: baseURL)
        networking.downloadImage("/image/png") { image, error in
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }

    func testImageDownload() {
        let networking = Networking(baseURL: baseURL)
        networking.downloadImage("/image/png") { image, error in
            XCTAssertNotNil(image)
            let pigImage = UIImage(named: "pig.png", inBundle: NSBundle(forClass: Tests.self), compatibleWithTraitCollection: nil)!
            let pigImageData = UIImagePNGRepresentation(pigImage)
            let imageData = UIImagePNGRepresentation(image!)
            XCTAssertEqual(pigImageData, imageData)
        }
    }

    func testDestinationURL() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        let destinationURL = networking.destinationURL(path)
        XCTAssertEqual(destinationURL.lastPathComponent!, "http:--httpbin.org-image-png")
    }

    func testImageDownloadCache() {
        let networking = Networking(baseURL: baseURL)
        let path = "/image/png"
        networking.downloadImage(path) { image, error in
        }

        let destinationURL = networking.destinationURL(path)
        XCTAssertTrue(NSFileManager().fileExistsAtPath(destinationURL.path!))
    }

    func testCancelImageDownload() {
        let expectation = expectationWithDescription("testCancelImageDownload")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true
        networking.downloadImage("/image/png") { image, error in
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
        let pigImage = UIImage(named: "pig.png", inBundle: NSBundle(forClass: Tests.self), compatibleWithTraitCollection: nil)!
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

// MARK: Other

extension Tests {
    func testBasicAuth() {
        let networking = Networking(baseURL: baseURL)
        networking.autenticate("user", password: "passwd")
        networking.GET("/basic-auth/user/passwd", completion: { JSON, error in
            let JSON = JSON as! [String : AnyObject]
            let user = JSON["user"] as! String
            let authenticated = JSON["authenticated"] as! Bool
            XCTAssertEqual(user, "user")
            XCTAssertEqual(authenticated, true)
        })
    }

    func testURLForPath() {
        let networking = Networking(baseURL: baseURL)
        let url = networking.urlForPath("/hello")
        XCTAssertEqual(url.absoluteString, "http://httpbin.org/hello")
    }

    func testSkipTestMode() {
        let expectation = expectationWithDescription("testSkipTestMode")

        let networking = Networking(baseURL: baseURL)
        networking.disableTestingMode = true

        var synchronous = false
        networking.GET("/get", completion: { JSON, error in
            synchronous = true

            XCTAssertTrue(synchronous)

            expectation.fulfill()
        })

        XCTAssertFalse(synchronous)

        waitForExpectationsWithTimeout(3.0, handler: nil)
    }
}
