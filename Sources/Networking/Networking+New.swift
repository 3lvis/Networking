import Foundation

extension Networking {
    func handle<T: Decodable>(_ requestType: RequestType, path: String, parameters: Any?, cachingLevel: CachingLevel = .none) async -> Result<T, NetworkingError> {
        do {
            logger.info("Starting \(requestType.rawValue) request to \(path, privacy: .public)")

            if let fakeRequest = try FakeRequest.find(ofType: requestType, forPath: path, in: fakeRequests) {
                return try await handleFakeRequest(fakeRequest, path: path, requestType: requestType)
            }

            let request = try createRequest(path: path, requestType: requestType, parameters: parameters)
            // Key the cache by the request's effective, percent-encoded path + query so requests
            // that differ only by parameter encoding don't collide (e.g. ["a": "1&b=2"] vs
            // ["a": 1, "b": 2]). Kept relative — destinationURL re-prepends the baseURL to derive
            // the cache filename and rejects an absolute URL here.
            let cacheKey = cacheKey(for: request, fallbackPath: path)
            if cachingLevel != .none,
                let cachedData = try objectFromCache(for: cacheKey, cacheName: nil, cachingLevel: cachingLevel, responseType: .json) as? Data,
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
                    try? cacheOrPurgeData(data: encoded, path: cacheKey, cacheName: nil, cachingLevel: cachingLevel)
                }
            }
            return result

        } catch {
            return handleRequestError(error: error)
        }
    }

    // Cached payload for the new API: persists the original response's status code and headers
    // alongside the body so a cache hit reproduces the real response metadata, not fabricated values.
    private struct CachedResponse: Codable {
        let statusCode: Int
        let headers: [String: String]
        let body: Data
    }

    private func cacheKey(for request: URLRequest, fallbackPath: String) -> String {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return fallbackPath
        }
        // Sort the *encoded* query components so parameter order doesn't change the key (a cache
        // miss) while distinct encodings still produce distinct keys (no collision).
        let query = components.percentEncodedQuery
            .map { "?" + $0.split(separator: "&").sorted().joined(separator: "&") } ?? ""
        return components.percentEncodedPath + query
    }

    private func handleFakeRequest<T: Decodable>(_ fakeRequest: FakeRequest, path: String, requestType: RequestType) async throws -> Result<T, NetworkingError> {
        let (_, response, error) = try handleFakeRequest(fakeRequest, path: path, cacheName: nil, cachingLevel: .none)

        if fakeRequest.delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(fakeRequest.delay * 1_000_000_000))
        }

        let result = try JSONResult(body: fakeRequest.response, response: response, error: error)
        return try handleResponse(responseData: result.data, response: response, path: path)
    }

    private func createRequest(path: String, requestType: RequestType, parameters: Any?) throws -> URLRequest {
        // Split a query embedded in the path so it survives URL building instead of being
        // percent-encoded into the path (encodeUTF8 uses .urlPathAllowed, which escapes "?").
        let pathParts = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let rawPath = String(pathParts[0])
        let pathQuery = pathParts.count > 1 ? String(pathParts[1]) : nil

        guard var urlComponents = URLComponents(string: try composedURL(with: rawPath).absoluteString) else {
            throw URLError(.badURL)
        }

        // GET and DELETE carry parameters in the query string; merge them onto any query the
        // path already had rather than replacing it.
        let carriesQueryParameters = requestType == .get || requestType == .delete
        var queryItems = [URLQueryItem]()
        if let pathQuery, let parsed = URLComponents(string: "?\(pathQuery)")?.queryItems {
            queryItems.append(contentsOf: parsed)
        }
        if carriesQueryParameters, let queryParameters = parameters as? [String: Any] {
            queryItems.append(contentsOf: queryParameters.map { URLQueryItem(name: $0, value: "\($1)") })
        }
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }

        let parameterType: Networking.ParameterType? = (carriesQueryParameters || parameters == nil) ? nil : .json
        var request = URLRequest(
            url: url,
            requestType: requestType,
            path: path,
            parameterType: parameterType,
            responseType: .json,
            boundary: boundary,
            authorizationHeaderValue: authorizationHeaderValue,
            token: token,
            authorizationHeaderKey: authorizationHeaderKey,
            headerFields: headerFields
        )

        if !carriesQueryParameters, let parameters = parameters {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        }

        return request
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
        } else if T.self == NetworkingResponse.self {
            let headers = Dictionary(uniqueKeysWithValues: httpResponse.allHeaderFields.compactMap { key, value in
                (key as? String).map { ($0, AnyCodable(value)) }
            })
            let body = try JSONDecoder().decode([String: AnyCodable].self, from: responseData)
            let networkingJSON = NetworkingResponse(statusCode: httpResponse.statusCode, headers: headers, body: body)
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
        var errorDetails: [String: Any]? = nil
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
