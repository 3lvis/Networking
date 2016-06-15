import Foundation

extension Dictionary where Key: StringLiteralConvertible {
    func formURLEncodedFormat() -> String {
        var converted = ""
        for (index, entry) in self.enumerated() {
            if index > 0 {
                converted.append("&")
            }
            converted.append("\(entry.0)=\(entry.1)")
        }

        guard let encodedParameters = converted.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) else { fatalError("Couldn't convert parameters to form url: \(converted)") }
        return encodedParameters
    }
}
