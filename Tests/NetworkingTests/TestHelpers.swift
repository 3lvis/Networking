import Foundation
@testable import Networking

enum TestConfig {
    /// Base URL for httpbin-backed integration tests. Defaults to the public service;
    /// CI overrides it with HTTPBIN_BASE_URL to point at a locally-run go-httpbin instance.
    static let httpbinBaseURL = ProcessInfo.processInfo.environment["HTTPBIN_BASE_URL"] ?? "http://httpbin.org"
}

/// httpbin echoes request maps (headers/form/args/files) under a top-level key. httpbin.org
/// uses `String` values; go-httpbin uses `[String]`. Normalize either shape to `[String: String]`
/// so integration tests pass against both.
func httpbinEchoedMap(_ json: [String: Any], _ key: String) -> [String: String] {
    guard let raw = json[key] as? [String: Any] else { return [:] }
    var result: [String: String] = [:]
    for (mapKey, value) in raw {
        if let string = value as? String {
            result[mapKey] = string
        } else if let array = value as? [String], let first = array.first {
            result[mapKey] = first
        }
    }
    return result
}

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
