import Foundation

extension NSFileManager {
    public func fileExistsAtURL(url: NSURL) -> Bool {
        guard let path = url.path else { fatalError("Couldn't get path for url: \(url)") }

        return fileExistsAtPath(path)
    }

    public func removeFileAtURL(url: NSURL) {
        guard let path = url.path else { fatalError("Couldn't get path for url: \(url)") }

        do {
            try NSFileManager.defaultManager().removeItemAtPath(path)
        } catch let error as NSError {
            fatalError("Couldn't remove item at path: \(path), error: \(error)")
        }
    }
}