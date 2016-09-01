import Foundation
import XCTest

class UploadTests: XCTestCase {
    func testUpload() {
        var synchronous = false
        let baseURL = "http://192.168.1.70:8888"
        let networking = Networking(baseURL: baseURL)
        let url = NSBundle(forClass: UploadTests.self).URLForResource("tiny", withExtension: "mov")!
        networking.upload(path: "/upload.php", fileURL: url) { error in
            XCTAssertNil(error)
            synchronous = true
        }

        XCTAssertTrue(synchronous)
    }
}