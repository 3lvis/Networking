import Foundation

final class FakeRequest {
    // `.data` holds already-serialized JSON (or raw file bytes), served back as-is; `.image` is served
    // straight back by the image-download path.
    enum Payload {
        case none
        case data(Data)
        case image(Image)
    }

    struct Response {
        let payload: Payload
        let responseType: Networking.ResponseType
        let headerFields: [String: String]?
        let statusCode: Int
        let delay: Double

        func replacing(_ values: [String: String]) -> Response? {
            guard case .data(let data) = payload,
                let responseString = String(data: data, encoding: .utf8),
                let stringData = responseString.replacing(values).data(using: .utf8)
            else { return nil }

            return Response(
                payload: .data(stringData),
                responseType: responseType,
                headerFields: headerFields,
                statusCode: statusCode,
                delay: delay
            )
        }
    }

    private let responses: [Response]
    private var nextResponseIndex = 0

    private var firstResponse: Response { responses[0] }
    var payload: Payload { firstResponse.payload }
    var responseType: Networking.ResponseType { firstResponse.responseType }
    var headerFields: [String: String]? { firstResponse.headerFields }
    var statusCode: Int { firstResponse.statusCode }
    var delay: Double { firstResponse.delay }

    init(
        payload: Payload,
        responseType: Networking.ResponseType,
        headerFields: [String: String]?,
        statusCode: Int,
        delay: Double
    ) {
        self.init(responses: [Response(
            payload: payload,
            responseType: responseType,
            headerFields: headerFields,
            statusCode: statusCode,
            delay: delay
        )])
    }

    init(responses: [Response]) {
        precondition(!responses.isEmpty, "Networking: a fake response sequence must not be empty")
        self.responses = responses
    }

    func nextResponse() -> Response {
        let response = responses[nextResponseIndex]
        nextResponseIndex = min(nextResponseIndex + 1, responses.count - 1)
        return response
    }

    static func takeNext(
        ofType type: Networking.RequestType,
        forPath path: String,
        in collection: [Networking.RequestType: [String: FakeRequest]]
    ) throws -> Response? {
        guard let requests = collection[type], path.count > 0 else { return nil }

        if let request = requests[path] {
            return request.nextResponse()
        }

        guard let match = templatedMatch(forPath: path, in: requests) else { return nil }
        return match.request.nextResponse().replacing(match.values)
    }

    static func find(
        ofType type: Networking.RequestType,
        forPath path: String,
        in collection: [Networking.RequestType: [String: FakeRequest]]
    ) throws -> FakeRequest? {
        guard let requests = collection[type], path.count > 0 else { return nil }

        if let result = requests[path] {
            return result
        }
        return templated(forPath: path, in: requests)
    }

    // A faked path may carry placeholders — "/users/{userID}" answers "/users/10" — so a lookup that
    // missed exactly walks the templated ones, and the values it captured are substituted into the body
    // as well as the path.
    private static func templated(forPath path: String, in requests: [String: FakeRequest]) -> FakeRequest? {
        guard let match = templatedMatch(forPath: path, in: requests),
            let response = match.request.firstResponse.replacing(match.values)
        else { return nil }
        return FakeRequest(responses: [response])
    }

    private static func templatedMatch(
        forPath path: String,
        in requests: [String: FakeRequest]
    ) -> (request: FakeRequest, values: [String: String])? {
        var evaluatedPath = path
        evaluatedPath.removeFirstLetterIfDash()
        evaluatedPath.removeLastLetterIfDash()
        let lookupPathParts = evaluatedPath.components(separatedBy: "/")

        for (originalFakedPath, fakeRequest) in requests {
            guard let replacedValues = captures(from: originalFakedPath, matching: lookupPathParts),
                originalFakedPath.replacing(replacedValues) == path,
                fakeRequest.firstResponse.replacing(replacedValues) != nil
            else { continue }
            return (fakeRequest, replacedValues)
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
