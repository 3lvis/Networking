import Foundation

struct FakeRequest {
    // `.data` holds already-serialized JSON (or raw file bytes), served back as-is; `.image` is served
    // straight back by the image-download path.
    enum Payload {
        case none
        case data(Data)
        case image(Image)
    }

    let payload: Payload
    let responseType: Networking.ResponseType
    let headerFields: [String: String]?
    let statusCode: Int
    let delay: Double

    init(payload: Payload, responseType: Networking.ResponseType, headerFields: [String : String]?, statusCode: Int, delay: Double) {
        self.payload = payload
        self.responseType = responseType
        self.headerFields = headerFields
        self.statusCode = statusCode
        self.delay = delay
    }

    static func find(ofType type: Networking.RequestType, forPath path: String, in collection: [Networking.RequestType: [String: FakeRequest]]) throws -> FakeRequest? {
        guard let requests = collection[type] else { return nil }
        guard path.count > 0 else { return nil }

        if let result = requests[path] {
            return result
        } else {
            var evaluatedPath = path
            evaluatedPath.removeFirstLetterIfDash()
            evaluatedPath.removeLastLetterIfDash()
            let lookupPathParts = evaluatedPath.components(separatedBy: "/")

            for (originalFakedPath, fakeRequest) in requests {
                guard originalFakedPath.contains("{") else { continue }

                var fakedPath = originalFakedPath
                fakedPath.removeFirstLetterIfDash()
                fakedPath.removeLastLetterIfDash()
                let fakePathParts = fakedPath.components(separatedBy: "/")

                guard lookupPathParts.count == fakePathParts.count else { continue }
                guard lookupPathParts.first == fakePathParts.first else { continue }
                guard lookupPathParts.count != 1 && fakePathParts.count != 1 else { continue }

                var replacedValues = [String: String]()
                for (index, fakePathPart) in fakePathParts.enumerated() {
                    if fakePathPart.contains("{") {
                        replacedValues[fakePathPart] = lookupPathParts[index]
                    }
                }

                var replacedPath = originalFakedPath
                for (key, value) in replacedValues {
                    replacedPath = replacedPath.replacingOccurrences(of: key, with: value)
                }
                guard replacedPath == path else { continue }
                // Substitute the captured path values into the JSON body string (e.g. "{userID}" -> "10").
                guard case let .data(data) = fakeRequest.payload,
                      var responseString = String(data: data, encoding: .utf8) else { continue }

                for (key, value) in replacedValues {
                    responseString = responseString.replacingOccurrences(of: key, with: value)
                }

                guard let stringData = responseString.data(using: .utf8) else { continue }
                return FakeRequest(payload: .data(stringData), responseType: fakeRequest.responseType, headerFields: fakeRequest.headerFields, statusCode: fakeRequest.statusCode, delay: fakeRequest.delay)
            }
        }

        return nil
    }
}

extension String {

    mutating func removeFirstLetterIfDash() {
        let initialCharacter = String(self[..<index(after: startIndex)])
        if initialCharacter == "/" {
            if count > 1 {
                remove(at: startIndex)
            } else {
                self = ""
            }
        }
    }

    mutating func removeLastLetterIfDash() {
        let initialCharacter: String
        if count > 1 {
            initialCharacter = String(self[index(endIndex, offsetBy: -1)...])
        } else {
            initialCharacter = String(self[..<endIndex])
        }

        if initialCharacter == "/" {
            if count > 1 {
                remove(at: index(endIndex, offsetBy: -1))
            } else {
                self = ""
            }
        }
    }
}
