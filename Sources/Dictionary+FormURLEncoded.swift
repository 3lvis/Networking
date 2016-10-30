import Foundation

public extension Dictionary where Key: ExpressibleByStringLiteral {

    /**
     Returns the parameters in using URL-enconding, for example ["username": "Michael", "age": 20] will become "username=Michael&age=20".
     */
    public func urlEncodedString() -> String {
        let converted = self.map { key, value in "\(key)=\(value)" }.joined(separator: "&")
        guard let encodedParameters = converted.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) else { fatalError("Couldn't encode parameters: \(converted)") }

        return encodedParameters
    }
}
