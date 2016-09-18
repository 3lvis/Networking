import Foundation

struct Helper {

    static func removeFileIfNeeded(_ networking: Networking, path: String, cacheName: String? = nil) {
        guard let destinationURL = try? networking.destinationURL(for: path, cacheName: cacheName) else { fatalError("Couldn't get destination URL for path: \(path) and cacheName: \(cacheName)") }
        if FileManager.default.exists(at: destinationURL) {
            FileManager.default.remove(at: destinationURL)
        }
    }
}
