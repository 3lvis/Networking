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

    static func find(
        ofType type: Networking.RequestType,
        forPath path: String,
        in collection: [Networking.RequestType: [String: FakeRequest]]
    ) throws -> FakeRequest? {
        guard let requests = collection[type] else { return nil }
        guard path.count > 0 else { return nil }

        if let result = requests[path] {
            return result
        }
        return templated(forPath: path, in: requests)
    }

    // A faked path may carry placeholders — "/users/{userID}" answers "/users/10" — so a lookup that
    // missed exactly walks the templated ones, and the values it captured are substituted into the body
    // as well as the path.
    private static func templated(forPath path: String, in requests: [String: FakeRequest]) -> FakeRequest? {
        var evaluatedPath = path
        evaluatedPath.removeFirstLetterIfDash()
        evaluatedPath.removeLastLetterIfDash()
        let lookupPathParts = evaluatedPath.components(separatedBy: "/")

        for (originalFakedPath, fakeRequest) in requests {
            guard let replacedValues = captures(from: originalFakedPath, matching: lookupPathParts),
                originalFakedPath.replacing(replacedValues) == path
            else { continue }

            guard case .data(let data) = fakeRequest.payload,
                let responseString = String(data: data, encoding: .utf8)
            else { continue }

            let substituted = responseString.replacing(replacedValues)
            guard let stringData = substituted.data(using: .utf8) else { continue }
            return FakeRequest(
                payload: .data(stringData), responseType: fakeRequest.responseType,
                headerFields: fakeRequest.headerFields, statusCode: fakeRequest.statusCode, delay: fakeRequest.delay
            )
        }

        return nil
    }
    // The values a templated path captures from a lookup — "/users/{userID}" against "/users/10" gives
    // ["{userID}": "10"] — or nil where the two do not describe the same path at all.
    private static func captures(from fakedPath: String, matching lookupPathParts: [String]) -> [String: String]? {
        guard fakedPath.contains("{") else { return nil }

        var trimmed = fakedPath
        trimmed.removeFirstLetterIfDash()
        trimmed.removeLastLetterIfDash()
        let fakePathParts = trimmed.components(separatedBy: "/")

        guard lookupPathParts.count == fakePathParts.count,
            lookupPathParts.first == fakePathParts.first,
            lookupPathParts.count != 1
        else { return nil }

        var captured = [String: String]()
        for (index, fakePathPart) in fakePathParts.enumerated() where fakePathPart.contains("{") {
            captured[fakePathPart] = lookupPathParts[index]
        }
        return captured
    }

}

extension String {

    // Placeholder -> captured value, applied to whichever string carries the placeholders.
    func replacing(_ values: [String: String]) -> String {
        values.reduce(self) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
    }

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
