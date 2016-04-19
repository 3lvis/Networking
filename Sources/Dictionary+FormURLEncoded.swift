import Foundation

extension Dictionary where Key: StringLiteralConvertible {
    func formURLEncodedFormat() -> String {
        var converted = ""
        for (index, entry) in self.enumerate() {
            if index > 0 {
                converted.appendContentsOf("&")
            }
            converted.appendContentsOf("\(entry.0)=\(entry.1)")
        }

        guard let encodedParameters = converted.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet()) else { fatalError("Couldn't convert parameters to form url: \(converted)") }
        return encodedParameters
    }
}