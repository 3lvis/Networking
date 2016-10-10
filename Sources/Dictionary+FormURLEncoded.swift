import Foundation

public extension Dictionary where Key: ExpressibleByStringLiteral {

    public func formURLEncodedFormat() -> String {
        let converted = self.map { name, value in "\(name)=\(value)" }.joined(separator: "&")
        guard let encodedParameters = converted.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) else { fatalError("Couldn't convert parameters to form url: \(converted)") }

        return encodedParameters
    }
}
