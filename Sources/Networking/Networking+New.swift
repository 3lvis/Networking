import Foundation

extension Networking {
    // Typed request payload. Replaces the old `parameters: Any?` + `ParameterType` pair: each
    // case carries exactly the data its encoding needs, so the wrong combination can't be expressed.
    enum RequestBody {
        case none
        case json(Data)                                       // pre-encoded JSON
        case formURLEncoded([String: String])
        case multipart(fields: [String: String], parts: [FormDataPart])
        case raw(Data, contentType: String)

        // Multipart's content type needs the boundary, which only the actor knows, so it's passed in.
        func contentType(boundary: String) -> String? {
            switch self {
            case .none: return nil
            case .json: return "application/json"
            case .formURLEncoded: return "application/x-www-form-urlencoded"
            case .multipart: return "multipart/form-data; boundary=\(boundary)"
            case let .raw(_, contentType): return contentType
            }
        }
    }

    func handle<T: Decodable>(_ requestType: RequestType, path: String, body: RequestBody = .none, query: [URLQueryItem] = [], cachingLevel: CachingLevel = .none) async -> Result<T, NetworkingError> {
        do {
            logger.info("Starting \(requestType.rawValue) request to \(path, privacy: .public)")

            if let fakeRequest = try FakeRequest.find(ofType: requestType, forPath: path, in: fakeRequests) {
                return try await handleFakeRequest(fakeRequest, path: path, requestType: requestType)
            }

            let request = try createRequest(path: path, requestType: requestType, body: body, query: query)
            // Key off the request's full effective URL so distinct requests never collide (e.g.
            // full-URL GETs to different hosts). Passed as the cacheName so destinationURL uses it
            // verbatim instead of re-prepending the baseURL.
            let cacheKey = cacheKey(for: request, fallbackPath: path)
            if cachingLevel != .none,
                let cachedData = try objectFromCache(for: path, cacheName: cacheKey, cachingLevel: cachingLevel, responseType: .json) as? Data,
                let cached = try? JSONDecoder().decode(CachedResponse.self, from: cachedData),
                let url = request.url,
                let cachedResponse = HTTPURLResponse(url: url, statusCode: cached.statusCode, httpVersion: nil, headerFields: cached.headers) {
                return try handleSuccessfulResponse(responseData: cached.body, path: path, httpResponse: cachedResponse)
            }

            let (responseData, response) = try await session.data(for: request)
            let result: Result<T, NetworkingError> = try handleResponse(responseData: responseData, response: response, path: path)
            if cachingLevel != .none, case .success = result, let httpResponse = response as? HTTPURLResponse {
                let headers = Dictionary(uniqueKeysWithValues: httpResponse.allHeaderFields.compactMap { key, value in
                    (key as? String).map { ($0, "\(value)") }
                })
                let envelope = CachedResponse(statusCode: httpResponse.statusCode, headers: headers, body: responseData)
                if let encoded = try? JSONEncoder().encode(envelope) {
                    try? cacheOrPurgeData(data: encoded, path: path, cacheName: cacheKey, cachingLevel: cachingLevel)
                }
            }
            return result

        } catch {
            return handleRequestError(error: error)
        }
    }

    // Persists the response's status code and headers so a cache hit reproduces real metadata, not fabricated values.
    private struct CachedResponse: Codable {
        let statusCode: Int
        let headers: [String: String]
        let body: Data
    }

    private func cacheKey(for request: URLRequest, fallbackPath: String) -> String {
        guard let url = request.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return fallbackPath
        }
        // Sort the *encoded* query components so parameter order doesn't change the key (a cache
        // miss) while distinct encodings still produce distinct keys (no collision).
        if let query = components.percentEncodedQuery {
            components.percentEncodedQuery = query.split(separator: "&").sorted().joined(separator: "&")
        }
        return components.string ?? url.absoluteString
    }

    private func handleFakeRequest<T: Decodable>(_ fakeRequest: FakeRequest, path: String, requestType: RequestType) async throws -> Result<T, NetworkingError> {
        let (response, _) = try handleFakeRequest(fakeRequest, path: path, cacheName: nil, cachingLevel: .none)

        if fakeRequest.delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(fakeRequest.delay * 1_000_000_000))
        }

        // handleResponse routes success/failure off the fake's HTTP status code, so an empty body is fine.
        let responseData: Data
        if case let .data(data) = fakeRequest.payload {
            responseData = data
        } else {
            responseData = Data()
        }
        return try handleResponse(responseData: responseData, response: response, path: path)
    }

    private func createRequest(path: String, requestType: RequestType, body: RequestBody, query: [URLQueryItem]) throws -> URLRequest {
        // Split a query embedded in the path so it survives URL building instead of being
        // percent-encoded into the path (encodeUTF8 uses .urlPathAllowed, which escapes "?").
        let pathParts = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let rawPath = String(pathParts[0])
        let pathQuery = pathParts.count > 1 ? String(pathParts[1]) : nil

        guard var urlComponents = URLComponents(string: try composedURL(with: rawPath).absoluteString) else {
            throw URLError(.badURL)
        }

        // Merge typed query items onto any query the path already carried rather than replacing it.
        var queryItems = [URLQueryItem]()
        if let pathQuery, let parsed = URLComponents(string: "?\(pathQuery)")?.queryItems {
            queryItems.append(contentsOf: parsed)
        }
        queryItems.append(contentsOf: query)
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(
            url: url,
            requestType: requestType,
            path: path,
            contentType: body.contentType(boundary: boundary),
            responseType: .json,
            authorizationHeaderValue: authorizationHeaderValue,
            token: token,
            authorizationHeaderKey: authorizationHeaderKey,
            headerFields: headerFields
        )

        request.httpBody = try httpBody(body)

        return request
    }

    private func httpBody(_ body: RequestBody) throws -> Data? {
        switch body {
        case .none:
            return nil
        case let .json(data):
            return data
        case let .formURLEncoded(parameters):
            return try parameters.urlEncodedString().data(using: .utf8)
        case let .multipart(fields, parts):
            var bodyData = Data()
            for (key, value) in fields {
                var body = ""
                body += "--\(boundary)\r\n"
                body += "Content-Disposition: form-data; name=\"\(key)\""
                body += "\r\n\r\n\(value)\r\n"
                bodyData.append(body.data(using: .utf8)!)
            }
            for var part in parts {
                part.boundary = boundary
                bodyData.append(part.formData as Data)
            }
            bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
            return bodyData
        case let .raw(data, _):
            return data
        }
    }

    private func handleResponse<T: Decodable>(responseData: Data, response: URLResponse, path: String) throws -> Result<T, NetworkingError> {
        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.invalidResponse)
        }

        let statusCode = httpResponse.statusCode

        switch statusCode.statusCodeType {
        case .informational, .successful:
            return try handleSuccessfulResponse(responseData: responseData, path: path, httpResponse: httpResponse)
        case .redirection:
            return .failure(.unexpectedError(statusCode: statusCode, message: "Redirection occurred."))
        case .clientError:
            if (statusCode == 401 || statusCode == 403),
               let callback = unauthorizedRequestCallback {
                callback()
            }

            return try handleClientError(responseData: responseData, statusCode: statusCode, path: path)
        case .serverError:
            return try handleServerError(responseData: responseData, statusCode: statusCode, path: path)
        case .cancelled:
            return .failure(.unexpectedError(statusCode: statusCode, message: "Request was cancelled."))
        case .unknown:
            return .failure(.unexpectedError(statusCode: statusCode, message: "An unexpected error occurred."))
        }
    }

    private func handleSuccessfulResponse<T: Decodable>(responseData: Data, path: String, httpResponse: HTTPURLResponse) throws -> Result<T, NetworkingError> {
        if T.self == Data.self {
            return .success(Data() as! T)
        } else if T.self == JSONResponse.self {
            let headers = Dictionary(uniqueKeysWithValues: httpResponse.allHeaderFields.compactMap { key, value in
                (key as? String).map { ($0, AnyCodable(value)) }
            })
            // An empty body (e.g. 204 No Content) is a success — decoding empty data would fail, so use an empty body.
            let body = responseData.isEmpty ? [:] : try JSONDecoder().decode([String: AnyCodable].self, from: responseData)
            let networkingJSON = JSONResponse(statusCode: httpResponse.statusCode, headers: headers, body: body)
            return .success(networkingJSON as! T)
        } else {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decodedResponse = try decoder.decode(T.self, from: responseData)
            return .success(decodedResponse)
        }
    }

    private func handleClientError<T: Decodable>(responseData: Data, statusCode: Int, path: String) throws -> Result<T, NetworkingError> {
        let errorMessage = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: responseData) {
            return .failure(.clientError(statusCode: statusCode, message: errorResponse.combinedMessage))
        } else {
            return .failure(.clientError(statusCode: statusCode, message: errorMessage))
        }
    }

    private func handleServerError<T: Decodable>(responseData: Data, statusCode: Int, path: String) throws -> Result<T, NetworkingError> {
        let errorMessage = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        var errorDetails: [String: any Sendable]? = nil
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: responseData) {
            errorDetails = ["error": errorResponse.error ?? "",
                            "message": errorResponse.message ?? "",
                            "errors": errorResponse.errors ?? [:]]
            return .failure(.serverError(statusCode: statusCode, message: errorResponse.combinedMessage, details: errorDetails))
        } else {
            return .failure(.serverError(statusCode: statusCode, message: errorMessage, details: errorDetails))
        }
    }

    private func handleRequestError<T: Decodable>(error: Error) -> Result<T, NetworkingError> {
        if error is CancellationError || (error as? URLError)?.code == .cancelled {
            return .failure(.cancelled)
        }
        if let decodingError = error as? DecodingError {
            logger.error("Unexpected error occurred: \(decodingError.detailedMessage, privacy: .public)")
        } else {
            logger.error("Unexpected error occurred: \(error.localizedDescription, privacy: .public)")
        }
        return .failure(.unexpectedError(statusCode: nil, message: "Failed to process request (error: \(error.localizedDescription))."))
    }
}
