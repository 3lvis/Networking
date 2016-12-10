import Foundation

public extension Dictionary where Key: ExpressibleByStringLiteral {

    /**
     Returns the parameters in using URL-enconding, for example ["username": "Michael", "age": 20] will become "username=Michael&age=20".
     */
    public func urlEncodedString() -> String {
        let keys = self.map { key, value -> String in
            // Does not include "?" or "/" due to RFC 3986 - Section 3.4
            let generalDelimitersToEncode = ":#[]@"
            let subDelimitersToEncode = "!$&'()*+,;="

            var allowedCharacterSet = CharacterSet.urlQueryAllowed
            allowedCharacterSet.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")

            let encodedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: allowedCharacterSet)
            if let encodedValue = encodedValue {
                return "\(key)=\(encodedValue)"
            } else {
                fatalError("Couldn't encode \(value)")
            }
        }
        let converted = keys.joined(separator: "&")

        return converted
    }
}
