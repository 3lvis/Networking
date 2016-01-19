import Networking
import XCTest

class NSError_NetworkingTests: XCTestCase {
    func testNetworkingErrorType() {
        let error = NSError(domain: "", code: 400, userInfo: nil)
        XCTAssertEqual(error.networkingErrorType(), NetworkingErrorType.Client(400))
    }
}
