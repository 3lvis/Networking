import Foundation
import os.log

extension Networking {
    enum RequestBody {
        case none
        case json(Data)
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
            case .raw(_, let contentType): return contentType
            }
        }
    }

    func handle<T: Decodable>(
        _ requestType: RequestType, path: String, body: RequestBody = .none, query: [URLQueryItem] = [],
        cachingLevel: CachingLevel = .none
    ) async -> Result<T, NetworkingError> {
        let requestID = UUID()
        let clock = ContinuousClock()
        let startInstant = clock.now

        var context: RequestContext?
        let result: Result<T, NetworkingError>
        var statusCode: Int?
        var byteCount = 0
        var metrics: TransactionMetrics?
        var responseMetadata: ResponseMetadata?

        do {
            if let fakeRequest = try FakeRequest.find(ofType: requestType, forPath: path, in: fakeRequests) {
                let fakeContext = RequestContext(
                    id: requestID, requestType: requestType, url: try? composedURL(with: path), headers: headerFields)
                context = fakeContext
                emit(.started(fakeContext))
                let (fakeResult, fakeStatus, fakeBytes): (Result<T, NetworkingError>, Int, Int) =
                    try await handleFakeRequest(fakeRequest, path: path, requestType: requestType)
                result = fakeResult
                statusCode = fakeStatus
                byteCount = fakeBytes
            } else {
                let request = try createRequest(path: path, requestType: requestType, body: body, query: query)
                let requestContext = RequestContext(
                    id: requestID, requestType: requestType, url: request.url, headers: request.allHTTPHeaderFields)
                context = requestContext
                emit(.started(requestContext))

                // Key off the request's full effective URL so distinct requests never collide, passed as
                // the cacheName so destinationURL uses it verbatim instead of re-prepending the baseURL.
                let cacheKey = cacheKey(for: request, fallbackPath: path)
                if cachingLevel != .none,
                    let cachedData = try objectFromCache(
                        for: path, cacheName: cacheKey, cachingLevel: cachingLevel, responseType: .json) as? Data,
                    let cached = try? JSONDecoder().decode(CachedResponse.self, from: cachedData),
                    let url = request.url,
                    let cachedResponse = HTTPURLResponse(
                        url: url, statusCode: cached.statusCode, httpVersion: nil, headerFields: cached.headers)
                {
                    // Run the cache hit back out through the interceptor chain so validators apply to it too.
                    let exchange = try await perform(
                        request, cached: HTTPExchange(data: cached.body, response: cachedResponse))
                    result = handleResponse(responseData: exchange.data, response: exchange.response, path: path)
                    statusCode = exchange.response.statusCode
                    byteCount = exchange.data.count
                    responseMetadata = ResponseMetadata(response: exchange.response, body: exchange.data)
                } else {
                    let collector = MetricsCollector()
                    let exchange = try await perform(request, collector: collector)
                    let responseData = exchange.data
                    let response: URLResponse = exchange.response
                    let networkResult: Result<T, NetworkingError> = handleResponse(
                        responseData: responseData, response: response, path: path)
                    if cachingLevel != .none, case .success = networkResult,
                        let httpResponse = response as? HTTPURLResponse
                    {
                        let headers = Dictionary(
                            uniqueKeysWithValues: httpResponse.allHeaderFields.compactMap { key, value in
                                (key as? String).map { ($0, "\(value)") }
                            })
                        let envelope = CachedResponse(
                            statusCode: httpResponse.statusCode, headers: headers, body: responseData)
                        if let encoded = try? JSONEncoder().encode(envelope) {
                            try? cacheOrPurgeData(
                                data: encoded, path: path, cacheName: cacheKey, cachingLevel: cachingLevel)
                        }
                    }
                    result = networkResult
                    statusCode = (response as? HTTPURLResponse)?.statusCode
                    byteCount = responseData.count
                    metrics = collector.metrics.flatMap(TransactionMetrics.init)
                    if let httpResponse = response as? HTTPURLResponse {
                        responseMetadata = ResponseMetadata(response: httpResponse, body: responseData)
                    }
                }
            }
        } catch {
            // A failure before the request context was built (e.g. URL building) still emits a paired
            // .started/.completed so observers see every request.
            if context == nil {
                let errorContext = RequestContext(
                    id: requestID, requestType: requestType, url: nil, headers: headerFields)
                context = errorContext
                emit(.started(errorContext))
            }
            result = mapThrownError(error, path: path)
        }

        let duration = clock.now - startInstant
        guard let context else { return result }
        return complete(
            result, context: context, statusCode: statusCode, byteCount: byteCount, metrics: metrics,
            duration: duration, requestBody: body, responseMetadata: responseMetadata)
    }

    // Runs the interceptor chain. On a cache hit, `cached` is the base result the chain folds around (no
    // network call), so validators still see it. session/collector are read into locals first so the
    // @Sendable chain captures no actor-isolated state (Swift 6 region isolation).
    func perform(_ request: URLRequest, collector: MetricsCollector? = nil, cached: HTTPExchange? = nil) async throws
        -> HTTPExchange
    {
        let session = self.session
        let base: @Sendable (URLRequest) async throws -> HTTPExchange = { request in
            if let cached { return cached }
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

    // The single completion path, shared by verbs, pre-flight failures, and downloads. `requestBody` and
    // `responseMetadata` aren't on the `.completed` event, so they're threaded here for logging only.
    func complete<T>(
        _ result: Result<T, NetworkingError>, context: RequestContext, statusCode: Int?, byteCount: Int,
        metrics: TransactionMetrics?, duration: Duration, requestBody: RequestBody? = nil,
        responseMetadata: ResponseMetadata? = nil
    ) -> Result<T, NetworkingError> {
        let outcome: Outcome
        switch result {
        case .success:
            outcome = .success(statusCode: statusCode ?? 0, byteCount: byteCount)
        case .failure(let error):
            outcome = .failure(error)
        }
        logCompletion(
            context: context, result: result, statusCode: statusCode, byteCount: byteCount, duration: duration,
            requestBody: requestBody, responseMetadata: responseMetadata)
        emit(.completed(context, outcome: outcome, duration: duration, metrics: metrics))
        return result
    }

    private func logCompletion<T>(
        context: RequestContext, result: Result<T, NetworkingError>, statusCode: Int?, byteCount: Int,
        duration: Duration, requestBody: RequestBody?, responseMetadata: ResponseMetadata?
    ) {
        guard logLevel != .none else { return }

        let line: String
        let level: OSLogType
        let error: NetworkingError?
        switch result {
        case .success:
            guard logLevel == .all else { return }
            line =
                "✓ \(context.method) \(context.url?.absoluteString ?? "") [\(context.id.uuidString)] \(statusCode ?? 0) (\(byteCount) bytes) in \(duration)"
            level = .info
            error = nil
        case .failure(let failure):
            guard !failure.isCancelled else { return }
            line =
                "✗ \(context.method) \(context.url?.absoluteString ?? "") [\(context.id.uuidString)] failed: \(failure.errorDescription ?? "request failed")"
            level = .error
            error = failure
        }

        record(line, level: level)
        // context.headers carry the real values (events() needs them); redaction happens only here, in
        // the log path.
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

    private func requestBodyString(_ body: RequestBody) -> String? {
        switch body {
        case .none:
            return nil
        case .json(let data), .raw(let data, _):
            return bodySnippet(from: data)
        case .formURLEncoded(let fields):
            return (try? fields.urlEncodedString()).flatMap { $0.isEmpty ? nil : $0 }
        case .multipart:
            return "<multipart/form-data>"
        }
    }

    // Emits the `.started`/`.completed` pair for a failure that happens before the network call (e.g.
    // body encoding), so observers don't miss it.
    func emitPreflightFailure<T: Decodable>(_ requestType: RequestType, path: String, error: NetworkingError) -> Result<
        T, NetworkingError
    > {
        let requestID = UUID()
        let context = RequestContext(
            id: requestID, requestType: requestType, url: try? composedURL(with: path), headers: headerFields)
        emit(.started(context))
        return complete(.failure(error), context: context, statusCode: nil, byteCount: 0, metrics: nil, duration: .zero)
    }

    // Persists status code and headers alongside the body so a cache hit reproduces real metadata.
    private struct CachedResponse: Codable {
        let statusCode: Int
        let headers: [String: String]
        let body: Data
    }

    private func cacheKey(for request: URLRequest, fallbackPath: String) -> String {
        guard let url = request.url,
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return fallbackPath
        }
        // Sort the *encoded* query components so parameter order doesn't change the key (a cache
        // miss) while distinct encodings still produce distinct keys (no collision).
        if let query = components.percentEncodedQuery {
            components.percentEncodedQuery = query.split(separator: "&").sorted().joined(separator: "&")
        }
        return components.string ?? url.absoluteString
    }

    private func handleFakeRequest<T: Decodable>(_ fakeRequest: FakeRequest, path: String, requestType: RequestType)
        async throws -> (Result<T, NetworkingError>, statusCode: Int, byteCount: Int)
    {
        let (response, _) = try handleFakeRequest(fakeRequest, path: path, cacheName: nil, cachingLevel: .none)

        if fakeRequest.delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(fakeRequest.delay * 1_000_000_000))
        }

        // handleResponse routes success/failure off the fake's HTTP status code, so an empty body is fine.
        let responseData: Data
        if case .data(let data) = fakeRequest.payload {
            responseData = data
        } else {
            responseData = Data()
        }
        let result: Result<T, NetworkingError> = handleResponse(
            responseData: responseData, response: response, path: path)
        return (result, response.statusCode, responseData.count)
    }

    private func createRequest(path: String, requestType: RequestType, body: RequestBody, query: [URLQueryItem]) throws
        -> URLRequest
    {
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
        case .json(let data):
            return data
        case .formURLEncoded(let parameters):
            return try parameters.urlEncodedString().data(using: .utf8)
        case .multipart(let fields, let parts):
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
        case .raw(let data, _):
            return data
        }
    }

    private func handleResponse<T: Decodable>(responseData: Data, response: URLResponse, path: String) -> Result<
        T, NetworkingError
    > {
        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.invalidResponse)
        }

        let statusCode = httpResponse.statusCode

        switch StatusCodeType(statusCode: statusCode) {
        case .informational, .successful:
            return handleSuccessfulResponse(responseData: responseData, path: path, httpResponse: httpResponse)
        case .cancelled:
            return .failure(.cancelled)
        case .redirection, .clientError, .serverError, .unknown:
            let error = HTTPError(
                statusCode: statusCode, metadata: ResponseMetadata(response: httpResponse, body: responseData))
            return .failure(.http(error))
        }
    }

    private func handleSuccessfulResponse<T: Decodable>(responseData: Data, path: String, httpResponse: HTTPURLResponse)
        -> Result<T, NetworkingError>
    {
        if T.self == Data.self {
            return .success(responseData as! T)
        } else if T.self == JSONResponse.self {
            let headers = Dictionary(
                uniqueKeysWithValues: httpResponse.allHeaderFields.compactMap { key, value in
                    (key as? String).map { ($0, AnyCodable(value)) }
                })
            do {
                // An empty body (e.g. 204 No Content) is a success — decoding empty data would fail, so use an empty body.
                let body =
                    responseData.isEmpty ? [:] : try JSONDecoder().decode([String: AnyCodable].self, from: responseData)
                let networkingJSON = JSONResponse(statusCode: httpResponse.statusCode, headers: headers, body: body)
                return .success(networkingJSON as! T)
            } catch let error as DecodingError {
                return .failure(.decoding(error, ResponseMetadata(response: httpResponse, body: responseData)))
            } catch {
                return .failure(.invalidResponse)  // JSONDecoder only throws DecodingError; unreachable.
            }
        } else {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                return .success(try decoder.decode(T.self, from: responseData))
            } catch let error as DecodingError {
                return .failure(.decoding(error, ResponseMetadata(response: httpResponse, body: responseData)))
            } catch {
                return .failure(.invalidResponse)  // JSONDecoder only throws DecodingError; unreachable.
            }
        }
    }

    private func bodySnippet(from data: Data, limit: Int = 512) -> String? {
        ResponseMetadata.bodySnippet(from: data, limit: limit)
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
        // Fallback for the rare internal NSError still in our domain (cache path-build, param encoding);
        // composedURL now throws a typed NetworkingError caught above.
        if (error as NSError).domain == Networking.domain {
            return .failure(.invalidRequest(.invalidURL(path)))
        }
        return .failure(.transport(URLError(.unknown)))
    }
}
