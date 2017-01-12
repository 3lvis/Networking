import Foundation
import XCTest

class UnauthorizedCompletionBlockTests: XCTestCase {
    let baseURL = "http://httpbin.org"

    func testUnauthorizedCompletionBlock() {
        let networking = Networking(baseURL: baseURL)
        var completionBlockExecuted = false 
        
        networking.unauthorizedRequestCompletion = {
            completionBlockExecuted = true
        }
        
        networking.GET("/basic-auth/user/passwd") {
            JSON, error in
            XCTAssertNotNil(error)
            XCTAssertTrue(completionBlockExecuted)
        }
    }
}

