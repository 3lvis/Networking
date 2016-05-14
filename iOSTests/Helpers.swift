import Foundation

struct Helper {
    static func removeFileIfNeeded(networking: Networking, path: String, cacheName: String? = nil) {
        let destinationURL = try! networking.destinationURL(path, cacheName: cacheName)
        if NSFileManager.defaultManager().fileExistsAtURL(destinationURL) {
            NSFileManager.defaultManager().removeFileAtURL(destinationURL)
        }
    }
}