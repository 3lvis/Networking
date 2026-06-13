import Foundation
import XCTest
@testable import Networking

class JSONIntegrationTests: XCTestCase {
    func testToJSON() async throws {
        guard let url = URL(string: "\(TestConfig.httpbinBaseURL)/get") else {
            XCTFail()
            return
        }
        let request = URLRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        do {
            let JSON = try data.toJSON() as? [String: Any]
            let url = JSON?["url"] as! String
            XCTAssertEqual(url, "\(TestConfig.httpbinBaseURL)/get")
        } catch {
            XCTFail()
        }
    }
}
