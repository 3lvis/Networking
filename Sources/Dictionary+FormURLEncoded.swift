import Foundation

public extension Dictionary where Key: ExpressibleByStringLiteral {

    /**
     Returns the parameters in using URL-enconding, for example ["username": "Michael", "age": 20] will become "username=Michael&age=20".
     */
    public func urlEncodedString() -> String {
        let keys = self.map { key, value -> String in
            var encodedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            encodedValue = encodedValue?.replacingOccurrences(of: "+", with: "%2B")
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
