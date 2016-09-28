import Foundation

struct Helper {

    static func removeFileIfNeeded(_ networking: Networking, path: String, cacheName: String? = nil) {
        guard let destinationURL = try? networking.destinationURL(for: path, cacheName: cacheName) else { fatalError("Couldn't get destination URL for path: \(path) and cacheName: \(cacheName)") }
        if FileManager.default.exists(at: destinationURL) {
            FileManager.default.remove(at: destinationURL)
        }
    }

    static func cleanDownloadsFolder() {
        if let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let folderURL = cachesURL.appendingPathComponent(URL(string: Networking.domain)!.absoluteString)
            print("folderURL: \(folderURL)")

            if FileManager.default.exists(at: folderURL) {
                FileManager.default.remove(at: folderURL)
            }
        }
    }
}
