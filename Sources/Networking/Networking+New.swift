import Foundation
import os.log

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

        var context: RequestContext?
        let result: Result<T, NetworkingError>
        var statusCode: Int?
        var byteCount = 0
        var metrics: TransactionMetrics?
        var responseMetadata: ResponseMetadata?   // response headers + body snippet, for full-detail logging

        do {
            if let fakeRequest = try FakeRequest.find(ofType: requestType, forPath: path, in: fakeRequests) {
                let fakeContext = makeContext(id: requestID, method: requestType.rawValue, url: try? composedURL(with: path), headers: headerFields ?? [:])
                context = fakeContext
                emit(.started(fakeContext))
                let (fakeResult, fakeStatus, fakeBytes): (Result<T, NetworkingError>, Int, Int) = try await handleFakeRequest(fakeRequest, path: path, requestType: requestType)
                result = fakeResult
                statusCode = fakeStatus
                byteCount = fakeBytes
            } else {
                let request = try createRequest(path: path, requestType: requestType, body: body, query: query)
                let requestContext = makeContext(id: requestID, method: requestType.rawValue, url: request.url, headers: request.allHTTPHeaderFields ?? [:])
                context = requestContext
                emit(.started(requestContext))

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
                    responseMetadata = makeResponseMetadata(cachedResponse, body: cached.body)
                } else {
                    // The per-task delegate collects URLSessionTaskMetrics for the .completed event.
                    let collector = MetricsCollector()
                    let exchange = try await perform(request, collector: collector)
                    let responseData = exchange.data
                    let response: URLResponse = exchange.response
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
                    if let httpResponse = response as? HTTPURLResponse {
                        responseMetadata = makeResponseMetadata(httpResponse, body: responseData)
                    }
                }
            }
        } catch {
            // A failure before the request context was built (e.g. URL building) still emits a paired
            // .started/.completed so observers see every request.
            if context == nil {
                let errorContext = makeContext(id: requestID, method: requestType.rawValue, url: nil, headers: headerFields ?? [:])
                context = errorContext
                emit(.started(errorContext))
            }
            result = mapThrownError(error, path: path)
        }

        let duration = clock.now - startInstant
        guard let context else { return result }
        return complete(result, context: context, statusCode: statusCode, byteCount: byteCount, metrics: metrics, duration: duration, requestBody: body, responseMetadata: responseMetadata)
    }

    // Runs the interceptor chain around the real network call. session/collector are read into locals first
    // so the @Sendable chain captures no actor-isolated state (Swift 6 region isolation).
    func perform(_ request: URLRequest, collector: MetricsCollector? = nil) async throws -> HTTPExchange {
        let session = self.session
        let base: @Sendable (URLRequest) async throws -> HTTPExchange = { request in
            let (data, response): (Data, URLResponse)
            if let collector {
                (data, response) = try await session.data(for: request, delegate: collector)
            } else {
                (data, response) = try await session.data(for: request)
            }
            guard let httpResponse = response as? HTTPURLResponse else { throw NetworkingError.invalidResponse }
            return HTTPExchange(data: data, response: httpResponse)
        }
        var next = base
        for interceptor in interceptors.reversed() {
            let chained = next
            next = { request in try await interceptor.intercept(request, next: chained) }
        }
        return try await next(request)
    }

    // The single completion path: builds the outcome, runs the built-in logging, and emits `.completed`.
    // Shared by the verb path, pre-flight failures, and downloads so all report identically. `requestBody`
    // and `responseMetadata` aren't on the event, so they're threaded here for the full-detail logging.
    func complete<T>(_ result: Result<T, NetworkingError>, context: RequestContext, statusCode: Int?, byteCount: Int, metrics: TransactionMetrics?, duration: Duration, requestBody: RequestBody? = nil, responseMetadata: ResponseMetadata? = nil) -> Result<T, NetworkingError> {
        let outcome: Outcome
        switch result {
        case .success:
            outcome = .success(statusCode: statusCode ?? 0, byteCount: byteCount)
        case let .failure(error):
            outcome = .failure(error)
        }
        logCompletion(context: context, result: result, statusCode: statusCode, byteCount: byteCount, duration: duration, requestBody: requestBody, responseMetadata: responseMetadata)
        emit(.completed(context, outcome: outcome, duration: duration, metrics: metrics))
        return result
    }

    // Built-in logging (synchronous, lossless): failures at `.failures` and `.all`, successes only at
    // `.all`, always with full detail (line, request + response headers, request + response bodies).
    private func logCompletion<T>(context: RequestContext, result: Result<T, NetworkingError>, statusCode: Int?, byteCount: Int, duration: Duration, requestBody: RequestBody?, responseMetadata: ResponseMetadata?) {
        guard logLevel != .none else { return }

        let line: String
        let level: OSLogType
        let error: NetworkingError?
        switch result {
        case .success:
            guard logLevel == .all else { return }   // successes are logged only at .all
            line = "✓ \(context.method) \(context.url?.absoluteString ?? "") [\(context.id.uuidString)] \(statusCode ?? 0) (\(byteCount) bytes) in \(duration)"
            level = .info
            error = nil
        case let .failure(failure):
            guard !failure.isCancelled else { return }   // failures logged at .failures and .all
            line = "✗ \(context.method) \(context.url?.absoluteString ?? "") [\(context.id.uuidString)] failed: \(failure.errorDescription ?? "request failed")"
            level = .error
            error = failure
        }

        record(line, level: level)
        // context.headers are the real values (events() needs them); redaction is applied here, in the
        // log path, only in release builds (redactsLogs).
        let requestHeaders = redactsLogs ? redactedHeaders(context.headers) : context.headers
        for (key, value) in requestHeaders.sorted(by: { $0.key < $1.key }) {
            record("  → \(key): \(value)", level: level)
        }
        let metadata = responseMetadata ?? error?.responseMetadata
        if let metadata {
            let responseHeaders = redactsLogs ? redactedHeaders(metadata.headers) : metadata.headers
            for (key, value) in responseHeaders.sorted(by: { $0.key < $1.key }) {
                record("  ← \(key): \(value)", level: level)
            }
        }
        if let requestBodyText = requestBody.flatMap(requestBodyString) {
            record("  → body: \(redactsLogs ? "<redacted>" : requestBodyText)", level: level)
        }
        if let responseBodyText = metadata?.bodySnippet {
            record("  ← body: \(redactsLogs ? "<redacted>" : responseBodyText)", level: level)
        }
    }

    // Best-effort string form of a request body for body logging.
    private func requestBodyString(_ body: RequestBody) -> String? {
        switch body {
        case .none:
            return nil
        case let .json(data), let .raw(data, _):
            return bodySnippet(from: data)
        case let .formURLEncoded(fields):
            return (try? fields.urlEncodedString()).flatMap { $0.isEmpty ? nil : $0 }
        case .multipart:
            return "<multipart/form-data>"
        }
    }

    // A request attempt that fails before reaching the network (e.g. body/parameter encoding) still emits
    // the same `.started`/`.completed` pair, routed through `complete`, so observers don't miss it.
    func emitPreflightFailure<T: Decodable>(_ requestType: RequestType, path: String, error: NetworkingError) -> Result<T, NetworkingError> {
        let requestID = UUID()
        let context = makeContext(id: requestID, method: requestType.rawValue, url: try? composedURL(with: path), headers: headerFields ?? [:])
        emit(.started(context))
        return complete(.failure(error), context: context, statusCode: nil, byteCount: 0, metrics: nil, duration: .zero)
    }

    func makeContext(id: UUID, method: String, url: URL?, headers: [String: String]) -> RequestContext {
        RequestContext(id: id, method: method, url: url, headers: headers)
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
            // Parse a recognized error body into a message; keep the raw (truncated) body in metadata regardless.
            let parsedMessage = (try? JSONDecoder().decode(ErrorResponse.self, from: responseData))?.combinedMessage
            let serverMessage = (parsedMessage?.isEmpty == false) ? parsedMessage : nil
            let error = HTTPError(statusCode: statusCode, metadata: makeResponseMetadata(httpResponse, body: responseData), serverMessage: serverMessage)
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
                return .failure(.decoding(error, makeResponseMetadata(httpResponse, body: responseData)))
            } catch {
                return .failure(.invalidResponse) // JSONDecoder only throws DecodingError; unreachable.
            }
        } else {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                return .success(try decoder.decode(T.self, from: responseData))
            } catch let error as DecodingError {
                return .failure(.decoding(error, makeResponseMetadata(httpResponse, body: responseData)))
            } catch {
                return .failure(.invalidResponse) // JSONDecoder only throws DecodingError; unreachable.
            }
        }
    }

    private func makeResponseMetadata(_ httpResponse: HTTPURLResponse, body: Data) -> ResponseMetadata {
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
        // An interceptor (or the network call) may throw an already-categorized error — pass it through intact.
        if let networkingError = error as? NetworkingError {
            return .failure(networkingError)
        }
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
