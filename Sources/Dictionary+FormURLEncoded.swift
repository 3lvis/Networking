import Foundation

public extension Dictionary where Key: ExpressibleByStringLiteral {

    /**
     Returns the parameters in using URL-enconding, for example ["username": "Michael", "age": 20] will become "username=Michael&age=20".
     */
    public func urlEncodedString() throws -> String {
        var failedMessage: String?
        let keys = self.map { key, value -> String in
            let encodedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryParametersAllowed)
            if let encodedValue = encodedValue {
                return "\(key)=\(encodedValue)"
            } else {
                failedMessage = "Couldn't encode \(value)"
                return ""
            }
        }

        if let failedMessage = failedMessage {
            throw NSError(domain: Networking.domain, code: 0, userInfo: [NSLocalizedDescriptionKey: failedMessage])
        }

        let converted = keys.joined(separator: "&")

        return converted
    }
}
