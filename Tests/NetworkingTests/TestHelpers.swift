import Foundation
@testable import Networking

/// A reference box so `@Sendable` callbacks can write a flag the test reads afterward.
/// @unchecked: the callback fires synchronously inside the awaited request, before the test reads it.
final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

extension AsyncStream {
    /// Drains the first `count` elements into an array, then stops. Tests call `events()` *before* the
    /// request (so the stream buffers), then `await stream.collect(n)` after to read what was emitted.
    func collect(_ count: Int) async -> [Element] {
        guard count > 0 else { return [] }
        var collected: [Element] = []
        for await element in self {
            collected.append(element)
            if collected.count == count { break }
        }
        return collected
    }
}

enum TestConfig {
    /// Base URL for httpbin-backed integration tests. Defaults to a local go-httpbin on :8080;
    /// CI sets HTTPBIN_BASE_URL to the same. Run one with `docker run -p 8080:8080 mccutchen/go-httpbin`.
    static let httpbinBaseURL = ProcessInfo.processInfo.environment["HTTPBIN_BASE_URL"] ?? "http://127.0.0.1:8080"
}

/// httpbin echoes request maps (headers/form/args/files) under a top-level key, with values as
/// either `String` or `[String]` depending on the server. Normalize both to `[String: String]`.
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

/// Same normalization for the new API's `JSONResponse`, whose body holds `AnyCodable` values.
func httpbinEchoedMap(_ response: JSONResponse, _ key: String) -> [String: String] {
    guard let raw = response.body[key]?.value as? [String: AnyCodable] else { return [:] }
    var result: [String: String] = [:]
    for (mapKey, value) in raw {
        if let string = value.value as? String {
            result[mapKey] = string
        } else if let array = value.value as? [AnyCodable], let first = array.first?.value as? String {
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
