import Foundation

extension CharacterSet {
    static var urlQueryParametersAllowed: CharacterSet {
        // Excludes "?" and "/" per RFC 3986 §3.4.
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'()*+,;="

        var allowedCharacterSet = CharacterSet.urlQueryAllowed
        allowedCharacterSet.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")

        return allowedCharacterSet
    }
}

public extension Dictionary where Key: ExpressibleByStringLiteral {

    func urlEncodedString() throws -> String {

        let pairs = try reduce([]) { current, keyValuePair -> [String] in
            if let encodedValue = "\(keyValuePair.value)".addingPercentEncoding(withAllowedCharacters: .urlQueryParametersAllowed) {
                return current + ["\(keyValuePair.key)=\(encodedValue)"]
            } else {
                throw NSError(domain: Networking.domain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Couldn't encode \(keyValuePair.value)"])
            }
        }

        let converted = pairs.joined(separator: "&")

        return converted
    }
}

extension String {

    func encodeUTF8() -> String? {
        if let url = URL(string: self), url.host != nil {
            return self
        }

        return self.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
    }
}

extension FileManager {

    public func exists(at url: URL) -> Bool {
        let path = url.path

        return fileExists(atPath: path)
    }

    public func remove(at url: URL) throws {
        let path = url.path
        // `isDeletableFile` is true for a missing file with a writable parent, so removeItem would
        // throw "couldn't be removed" on a cache miss. Only attempt removal when the file exists.
        guard FileManager.default.fileExists(atPath: path) else { return }

        try FileManager.default.removeItem(atPath: path)
    }
}

extension URLRequest {
    init(url: URL, requestType: Networking.RequestType, path _: String, contentType: String?, responseType: Networking.ResponseType, authorizationHeaderValue: String?, token: String?, authorizationHeaderKey: String, headerFields: [String: String]?) {
        self = URLRequest(url: url)
        httpMethod = requestType.rawValue

        if let contentType {
            addValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        if let accept = responseType.accept {
            addValue(accept, forHTTPHeaderField: "Accept")
        }

        if let authorizationHeader = authorizationHeaderValue {
            setValue(authorizationHeader, forHTTPHeaderField: authorizationHeaderKey)
        } else if let token = token {
            setValue("Bearer \(token)", forHTTPHeaderField: authorizationHeaderKey)
        }

        if let headerFields = headerFields {
            for (key, value) in headerFields {
                setValue(value, forHTTPHeaderField: key)
            }
        }
    }
}

extension URL {
    func getData() -> Data {
        let path = self.path
        guard let data = FileManager.default.contents(atPath: path) else { fatalError("Couldn't get image in destination url: \(self)") }

        return data
    }
}

extension HTTPURLResponse {
    convenience init(url: URL, headerFields: [String : String]? = nil, statusCode: Int) {
        self.init(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headerFields)!
    }
}

extension NSError {
    convenience init(statusCode: Int) {
        self.init(domain: Networking.domain, code: statusCode, userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: statusCode)])
    }
}
