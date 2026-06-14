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
        let requestID = UUID()
        let clock = ContinuousClock()
        let startInstant = clock.now
        record("→ \(requestType.rawValue) \(path) [\(requestID.uuidString)]", level: .info)

        var context: RequestContext?
        let result: Result<T, NetworkingError>
        var statusCode: Int?
        var byteCount = 0
        var metrics: TransactionMetrics?

        do {
            if let fakeRequest = try FakeRequest.find(ofType: requestType, forPath: path, in: fakeRequests) {
                let fakeContext = makeContext(id: requestID, method: requestType.rawValue, url: try? composedURL(with: path), headers: headerFields ?? [:])
                context = fakeContext
                observer?(.started(fakeContext))
                let (fakeResult, fakeStatus, fakeBytes): (Result<T, NetworkingError>, Int, Int) = try await handleFakeRequest(fakeRequest, path: path, requestType: requestType)
                result = fakeResult
                statusCode = fakeStatus
                byteCount = fakeBytes
            } else {
                let request = try createRequest(path: path, requestType: requestType, body: body, query: query)
                let requestContext = makeContext(id: requestID, method: requestType.rawValue, url: request.url, headers: request.allHTTPHeaderFields ?? [:])
                context = requestContext
                observer?(.started(requestContext))

                // Key off the request's full effective URL so distinct requests never collide (e.g.
                // full-URL GETs to different hosts). Passed as the cacheName so destinationURL uses it
                // verbatim instead of re-prepending the baseURL.
                let cacheKey = cacheKey(for: request, fallbackPath: path)
                if cachingLevel != .none,
                    let cachedData = try objectFromCache(for: path, cacheName: cacheKey, cachingLevel: cachingLevel, responseType: .json) as? Data,
                    let cached = try? JSONDecoder().decode(CachedResponse.self, from: cachedData),
                    let url = request.url,
                    let cachedResponse = HTTPURLResponse(url: url, statusCode: cached.statusCode, httpVersion: nil, headerFields: cached.headers) {
                    result = handleSuccessfulResponse(responseData: cached.body, path: path, httpResponse: cachedResponse)
                    statusCode = cached.statusCode
                    byteCount = cached.body.count
                } else {
                    // The per-task delegate collects URLSessionTaskMetrics for the .completed event.
                    let collector = MetricsCollector()
                    let (responseData, response) = try await session.data(for: request, delegate: collector)
                    let networkResult: Result<T, NetworkingError> = handleResponse(responseData: responseData, response: response, path: path)
                    if cachingLevel != .none, case .success = networkResult, let httpResponse = response as? HTTPURLResponse {
                        let headers = Dictionary(uniqueKeysWithValues: httpResponse.allHeaderFields.compactMap { key, value in
                            (key as? String).map { ($0, "\(value)") }
                        })
                        let envelope = CachedResponse(statusCode: httpResponse.statusCode, headers: headers, body: responseData)
                        if let encoded = try? JSONEncoder().encode(envelope) {
                            try? cacheOrPurgeData(data: encoded, path: path, cacheName: cacheKey, cachingLevel: cachingLevel)
                        }
                    }
                    result = networkResult
                    statusCode = (response as? HTTPURLResponse)?.statusCode
                    byteCount = responseData.count
                    metrics = collector.metrics.flatMap(TransactionMetrics.init)
                }
            }
        } catch {
            // A failure before the request context was built (e.g. URL building) still emits a paired
            // .started/.completed so observers see every request.
            if context == nil {
                let errorContext = makeContext(id: requestID, method: requestType.rawValue, url: nil, headers: headerFields ?? [:])
                context = errorContext
                observer?(.started(errorContext))
            }
            result = mapThrownError(error, path: path)
        }

        let duration = clock.now - startInstant
        let outcome: Outcome
        switch result {
        case .success:
            outcome = .success(statusCode: statusCode ?? 0, byteCount: byteCount)
            if let context {
                record("← \(statusCode ?? 0) (\(byteCount) bytes) in \(duration) [\(context.id.uuidString)]", level: .info)
            }
        case let .failure(error):
            outcome = .failure(error)
            // Out-of-the-box failure logging (os.Logger + optional file). Cancellations are intentional, so not logged as errors.
            if !error.isCancelled, let context {
                logFailure(context, error: error)
            }
        }
        if let context {
            observer?(.completed(context, outcome: outcome, duration: duration, metrics: metrics))
        }
        return result
    }

    private func makeContext(id: UUID, method: String, url: URL?, headers: [String: String]) -> RequestContext {
        RequestContext(id: id, method: method, url: url, headers: redactedHeaders(headers))
    }

    private func logFailure(_ context: RequestContext, error: NetworkingError) {
        var message = "✗ \(context.method) \(context.url?.absoluteString ?? "") [\(context.id.uuidString)] failed: \(error.errorDescription ?? "request failed")"
        if let snippet = error.responseMetadata?.bodySnippet {
            message += " — body: \(snippet)"
        }
        record(message, level: .error)
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

    private func handleFakeRequest<T: Decodable>(_ fakeRequest: FakeRequest, path: String, requestType: RequestType) async throws -> (Result<T, NetworkingError>, statusCode: Int, byteCount: Int) {
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
        let result: Result<T, NetworkingError> = handleResponse(responseData: responseData, response: response, path: path)
        return (result, response.statusCode, responseData.count)
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

    private func handleResponse<T: Decodable>(responseData: Data, response: URLResponse, path: String) -> Result<T, NetworkingError> {
        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.invalidResponse)
        }

        let statusCode = httpResponse.statusCode

        switch statusCode.statusCodeType {
        case .informational, .successful:
            return handleSuccessfulResponse(responseData: responseData, path: path, httpResponse: httpResponse)
        case .cancelled:
            return .failure(.cancelled)
        case .redirection, .clientError, .serverError, .unknown:
            if statusCode == 401 || statusCode == 403, let callback = unauthorizedRequestCallback {
                callback()
            }
            // Parse a recognized error body into a message; keep the raw (truncated) body in metadata regardless.
            let parsedMessage = (try? JSONDecoder().decode(ErrorResponse.self, from: responseData))?.combinedMessage
            let serverMessage = (parsedMessage?.isEmpty == false) ? parsedMessage : nil
            let error = HTTPError(statusCode: statusCode, metadata: responseMetadata(httpResponse, body: responseData), serverMessage: serverMessage)
            return .failure(.http(error))
        }
    }

    private func handleSuccessfulResponse<T: Decodable>(responseData: Data, path: String, httpResponse: HTTPURLResponse) -> Result<T, NetworkingError> {
        if T.self == Data.self {
            return .success(Data() as! T)
        } else if T.self == JSONResponse.self {
            let headers = Dictionary(uniqueKeysWithValues: httpResponse.allHeaderFields.compactMap { key, value in
                (key as? String).map { ($0, AnyCodable(value)) }
            })
            do {
                // An empty body (e.g. 204 No Content) is a success — decoding empty data would fail, so use an empty body.
                let body = responseData.isEmpty ? [:] : try JSONDecoder().decode([String: AnyCodable].self, from: responseData)
                let networkingJSON = JSONResponse(statusCode: httpResponse.statusCode, headers: headers, body: body)
                return .success(networkingJSON as! T)
            } catch let error as DecodingError {
                return .failure(.decoding(error, responseMetadata(httpResponse, body: responseData)))
            } catch {
                return .failure(.invalidResponse) // JSONDecoder only throws DecodingError; unreachable.
            }
        } else {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                return .success(try decoder.decode(T.self, from: responseData))
            } catch let error as DecodingError {
                return .failure(.decoding(error, responseMetadata(httpResponse, body: responseData)))
            } catch {
                return .failure(.invalidResponse) // JSONDecoder only throws DecodingError; unreachable.
            }
        }
    }

    private func responseMetadata(_ httpResponse: HTTPURLResponse, body: Data) -> ResponseMetadata {
        let headers = Dictionary(uniqueKeysWithValues: httpResponse.allHeaderFields.compactMap { key, value in
            (key as? String).map { ($0, "\(value)") }
        })
        return ResponseMetadata(statusCode: httpResponse.statusCode, headers: headers, bodySnippet: bodySnippet(from: body))
    }

    // A bounded, log-friendly view of the body — never the whole payload.
    private func bodySnippet(from data: Data, limit: Int = 512) -> String? {
        guard !data.isEmpty, let string = String(data: data, encoding: .utf8) else { return nil }
        guard string.count > limit else { return string }
        return String(string.prefix(limit)) + "… (truncated)"
    }

    private func mapThrownError<T: Decodable>(_ error: Error, path: String) -> Result<T, NetworkingError> {
        if error is CancellationError {
            return .failure(.cancelled)
        }
        if let urlError = error as? URLError {
            if urlError.code == .cancelled {
                return .failure(.cancelled)
            }
            if urlError.code == .badURL {
                return .failure(.invalidRequest(.invalidURL(path)))
            }
            return .failure(.transport(urlError))
        }
        // composedURL throws an NSError in our domain when the URL can't be built from baseURL + path.
        if (error as NSError).domain == Networking.domain {
            return .failure(.invalidRequest(.invalidURL(path)))
        }
        return .failure(.transport(URLError(.unknown)))
    }
}
