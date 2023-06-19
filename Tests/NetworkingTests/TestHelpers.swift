import Foundation
@testable import Networking

struct Helper {

    static func removeFileIfNeeded(_ networking: Networking, path: String, cacheName: String? = nil) throws {
        let destinationURL = try networking.destinationURL(for: path, cacheName: cacheName)
        if FileManager.default.exists(at: destinationURL) {
            try FileManager.default.remove(at: destinationURL)
        }
    }
}

extension Data {
    func toStringStringDictionary() throws -> [String: String] {
        let json = try JSONSerialization.jsonObject(with: self, options: [])
        if let receivedBody = json as? [String: String] {
            return receivedBody
        } else {
            return [String: String]()
        }
    }

    func toStringStringArray() throws -> [[String: String]] {
        let json = try JSONSerialization.jsonObject(with: self, options: [])
        if let receivedBody = json as? [[String: String]] {
            return receivedBody
        } else {
            return [[String: String]]()
        }
    }
}
