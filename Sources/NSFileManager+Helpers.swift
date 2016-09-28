import Foundation

extension FileManager {

    public func exists(at url: URL) -> Bool {
        let path = url.path

        return fileExists(atPath: path)
    }

    public func remove(at url: URL) {
        let path = url.path
        guard FileManager.default.isDeletableFile(atPath: url.path) else { return }

        do {
            try FileManager.default.removeItem(atPath: path)
        } catch let error as NSError {
            fatalError("Couldn't remove item at path: \(path), error: \(error)")
        }
    }
}
