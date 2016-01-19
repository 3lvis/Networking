import Foundation

public extension Dictionary where Key: StringLiteralConvertible {
    public func formURLEncodedFormat() -> String {
        var converted = ""
        for (index, entry) in self.enumerate() {
            if index > 0 {
                converted.appendContentsOf("&")
            }
            converted.appendContentsOf("\(entry.0)=\(entry.1)")
        }

        return converted.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
    }
}
