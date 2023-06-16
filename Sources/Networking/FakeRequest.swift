import Foundation

struct FakeRequest {
    let response: Any?
    let responseType: Networking.ResponseType
    let statusCode: Int

    static func find(ofType type: Networking.RequestType, forPath path: String, in collection: [Networking.RequestType: [String: FakeRequest]]) -> FakeRequest? {
        guard let requests = collection[type] else { return nil }

        guard path.count > 0 else { return nil }
        var evaluatedPath = path
        evaluatedPath.removeFirstLetterIfDash()
        evaluatedPath.removeLastLetterIfDash()
        let lookupPathParts = evaluatedPath.components(separatedBy: "/")

        for (originalFakedPath, fakeRequest) in requests {
            switch fakeRequest.responseType {
            case .data, .image:
                if originalFakedPath == path {
                    return fakeRequest
                } else {
                    return nil
                }
            case .json:
                if let response = fakeRequest.response {
                    var fakedPath = originalFakedPath
                    fakedPath.removeFirstLetterIfDash()
                    fakedPath.removeLastLetterIfDash()
                    let fakePathParts = fakedPath.components(separatedBy: "/")
                    guard lookupPathParts.count == fakePathParts.count else { continue }
                    guard lookupPathParts.first == fakePathParts.first else { continue }
                    guard lookupPathParts.count != 1 && fakePathParts.count != 1 else { return requests[originalFakedPath] }

                    var replacedValues = [String: String]()
                    for (index, fakePathPart) in fakePathParts.enumerated() {
                        if fakePathPart.contains("{") {
                            replacedValues[fakePathPart] = lookupPathParts[index]
                        }
                    }

                    var responseString = String(data: try! JSONSerialization.data(withJSONObject: response, options: .prettyPrinted), encoding: .utf8)!
                    for (key, value) in replacedValues {
                        responseString = responseString.replacingOccurrences(of: key, with: value)
                    }
                    let stringData = responseString.data(using: .utf8)
                    let finalJSON = try! JSONSerialization.jsonObject(with: stringData!, options: [])

                    return FakeRequest(response: finalJSON, responseType: fakeRequest.responseType, statusCode: fakeRequest.statusCode)
                } else if originalFakedPath == path {
                    return fakeRequest
                } else {
                    return nil
                }
            }
        }

        let result = requests[path]

        return result
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
