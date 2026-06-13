import Foundation

/// Error thrown while loading a JSON file (e.g. the file isn't found).
enum ParsingError: Error {
    case notFound
}

public extension FileManager {
    /// Returns a JSON object from a file.
    ///
    /// - Parameters:
    ///   - fileName: The name of the file, the expected extension is `.json`.
    ///   - bundle: The Bundle where the file is located, by default is the main bundle.
    /// - Returns: A JSON object, it can be either a Dictionary or an Array.
    /// - Throws: An error if it wasn't able to process the file.
    static func json(from fileName: String, bundle: Bundle = Bundle.main) throws -> Any? {
        var json: Any?

        guard let url = URL(string: fileName), let filePath = bundle.path(forResource: url.deletingPathExtension().absoluteString, ofType: url.pathExtension) else { throw ParsingError.notFound }
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        json = try data.toJSON()

        return json
    }
}

extension Data {

    /// Serializes Data into a JSON object.
    ///
    /// - Returns: A JSON object, it can be either a Dictionary or an Array.
    /// - Throws: An error if it couldn't serialize the data into json.
    public func toJSON() throws -> Any? {
        return try JSONSerialization.jsonObject(with: self, options: [])
    }
}
