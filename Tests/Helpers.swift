import Foundation

struct Helper {
    static func removeFileIfNeeded(networking: Networking, path: String, cacheName: String? = nil) {
        guard let destinationURL = try? networking.destinationURL(path, cacheName: cacheName) else { fatalError("Couldn't get destination URL for path: \(path) and cacheName: \(cacheName)") }
        if NSFileManager.defaultManager().fileExistsAtURL(destinationURL) {
            NSFileManager.defaultManager().removeFileAtURL(destinationURL)
        }
    }
}