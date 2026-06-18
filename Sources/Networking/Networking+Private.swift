import Foundation

extension Networking {
    nonisolated func objectFromCache(for path: String, cacheName: String?, cachingLevel: CachingLevel, responseType: ResponseType) throws -> Any? {
        try cacheStore.object(forResource: cacheResource(for: path, cacheName: cacheName), level: cachingLevel, asImage: responseType == .image)
    }

    func registerFake(requestType: RequestType, path: String, fileName: String, bundle: Bundle, statusCode: Int, delay: Double) {
        let url = URL(string: fileName)
        guard let resource = url?.deletingPathExtension().absoluteString,
              let filePath = bundle.path(forResource: resource, ofType: url?.pathExtension),
              let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            fatalError("We couldn't find \(fileName), are you sure is there?")
        }
        registerFake(requestType: requestType, path: path, headerFields: nil, payload: .data(data), responseType: .json, statusCode: statusCode, delay: delay)
    }

    func registerFake(requestType: RequestType, path: String, headerFields: [String: String]?, payload: FakeRequest.Payload, responseType: ResponseType, statusCode: Int, delay: Double) {
        var requests = fakeRequests[requestType] ?? [String: FakeRequest]()
        requests[path] = FakeRequest(payload: payload, responseType: responseType, headerFields: headerFields, statusCode: statusCode, delay: delay)
        fakeRequests[requestType] = requests
    }

    func handleFakeRequest(_ fakeRequest: FakeRequest, path: String, cacheName: String?, cachingLevel: CachingLevel) throws -> (HTTPURLResponse, NSError?) {
        var error: NSError?
        let url = try composedURL(with: path)
        let response = HTTPURLResponse(url: url, headerFields: fakeRequest.headerFields, statusCode: fakeRequest.statusCode)

        if StatusCodeType(statusCode: fakeRequest.statusCode) != .successful {
            error = NSError(statusCode: fakeRequest.statusCode)
        }

        // Images are served directly by handleImageRequest, so there's nothing to cache here.
        let data: Data? = { if case let .data(data) = fakeRequest.payload { return data } else { return nil } }()
        switch fakeRequest.responseType {
        case .image:
            try cacheOrPurgeImage(data: nil, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
        case .data, .json:
            try cacheOrPurgeData(data: data, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
        }
        return (response, error)
    }


    // Shared download skeleton: emit `.started`, time the work, map a thrown error to a download failure,
    // and emit `.completed`. The `work` closure does the type-specific fetch/cache/build and hands back the
    // result plus the `statusCode`/`byteCount` that `complete` reports (kept explicit because data and image
    // downloads set them differently — e.g. data caches before the status check, image caches success-only).
    private func performDownload<T>(_ requestType: RequestType, path: String, _ work: () async throws -> (result: Result<T, NetworkingError>, statusCode: Int?, byteCount: Int)) async -> Result<T, NetworkingError> {
        let clock = ContinuousClock()
        let startInstant = clock.now
        let context = RequestContext(id: UUID(), requestType: requestType, url: try? composedURL(with: path), headers: headerFields)
        emit(.started(context))

        let result: Result<T, NetworkingError>
        var statusCode: Int?
        var byteCount = 0
        do {
            (result, statusCode, byteCount) = try await work()
        } catch {
            result = .failure(downloadError(error))
        }
        return complete(result, context: context, statusCode: statusCode, byteCount: byteCount, metrics: nil, duration: clock.now - startInstant)
    }

    func handleDataRequest<T: DataDownloadable>(_ requestType: RequestType, path: String, cacheName: String?, cachingLevel: CachingLevel, responseType: ResponseType) async -> Result<T, NetworkingError> {
        await performDownload(requestType, path: path) {
            if let fakeRequests = fakeRequests[requestType], let fakeRequest = fakeRequests[path] {
                let (fakeResponse, _) = try handleFakeRequest(fakeRequest, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
                if fakeRequest.delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(fakeRequest.delay * 1_000_000_000))
                }
                if StatusCodeType(statusCode: fakeResponse.statusCode) != .successful {
                    return (.failure(downloadError(forStatusCode: fakeResponse.statusCode)), fakeResponse.statusCode, 0)
                } else if case let .data(fakeData) = fakeRequest.payload {
                    return (.success(T.makeDownloadResult(data: fakeData, statusCode: fakeResponse.statusCode, headers: headerFields(from: fakeResponse))), fakeResponse.statusCode, fakeData.count)
                } else {
                    return (.failure(.invalidResponse), fakeResponse.statusCode, 0)
                }
            } else if let cached = try objectFromCache(for: path, cacheName: cacheName, cachingLevel: cachingLevel, responseType: responseType) as? Data {
                let response = HTTPURLResponse(url: try composedURL(with: path), statusCode: 200)
                return (.success(T.makeDownloadResult(data: cached, statusCode: 200, headers: headerFields(from: response))), 200, 0)
            } else {
                let (downloaded, networkResponse) = try await requestData(requestType, path: path, responseType: responseType)
                try cacheOrPurgeData(data: downloaded, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
                if StatusCodeType(statusCode: networkResponse.statusCode) != .successful {
                    return (.failure(downloadError(forStatusCode: networkResponse.statusCode)), networkResponse.statusCode, 0)
                } else {
                    return (.success(T.makeDownloadResult(data: downloaded, statusCode: networkResponse.statusCode, headers: headerFields(from: networkResponse))), networkResponse.statusCode, downloaded.count)
                }
            }
        }
    }

    func handleImageRequest<T: ImageDownloadable>(_ requestType: RequestType, path: String, cacheName: String?, cachingLevel: CachingLevel, responseType: ResponseType) async -> Result<T, NetworkingError> {
        await performDownload(requestType, path: path) {
            if let fakeRequests = fakeRequests[requestType], let fakeRequest = fakeRequests[path] {
                let (fakeResponse, _) = try handleFakeRequest(fakeRequest, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
                if fakeRequest.delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(fakeRequest.delay * 1_000_000_000))
                }
                if StatusCodeType(statusCode: fakeResponse.statusCode) != .successful {
                    return (.failure(downloadError(forStatusCode: fakeResponse.statusCode)), fakeResponse.statusCode, 0)
                } else if case let .image(fakeImage) = fakeRequest.payload {
                    return (.success(T.makeDownloadResult(image: fakeImage, statusCode: fakeResponse.statusCode, headers: headerFields(from: fakeResponse))), fakeResponse.statusCode, 0)
                } else {
                    return (.failure(.invalidResponse), fakeResponse.statusCode, 0)
                }
            } else if let cached = try objectFromCache(for: path, cacheName: cacheName, cachingLevel: cachingLevel, responseType: responseType) as? Image {
                let response = HTTPURLResponse(url: try composedURL(with: path), statusCode: 200)
                return (.success(T.makeDownloadResult(image: cached, statusCode: 200, headers: headerFields(from: response))), 200, 0)
            } else {
                let (data, networkResponse) = try await requestData(requestType, path: path, responseType: responseType)
                if StatusCodeType(statusCode: networkResponse.statusCode) != .successful {
                    return (.failure(downloadError(forStatusCode: networkResponse.statusCode)), networkResponse.statusCode, 0)
                } else if let downloaded = try cacheOrPurgeImage(data: data, path: path, cacheName: cacheName, cachingLevel: cachingLevel) {
                    return (.success(T.makeDownloadResult(image: downloaded, statusCode: networkResponse.statusCode, headers: headerFields(from: networkResponse))), networkResponse.statusCode, data.count)
                } else {
                    return (.failure(.invalidResponse), networkResponse.statusCode, 0)
                }
            }
        }
    }

    private func headerFields(from response: HTTPURLResponse) -> [String: AnyCodable] {
        Dictionary(uniqueKeysWithValues: response.allHeaderFields.compactMap { key, value in
            (key as? String).map { ($0, AnyCodable(value)) }
        })
    }

    private func downloadError(forStatusCode statusCode: Int) -> NetworkingError {
        // Downloads don't retain the response body/headers at this point, so the metadata is status-only.
        let metadata = ResponseMetadata(statusCode: statusCode, headers: [:], body: Data())
        return .http(HTTPError(statusCode: statusCode, metadata: metadata))
    }

    private func downloadError(_ error: Error) -> NetworkingError {
        if error is CancellationError || (error as? URLError)?.code == .cancelled {
            return .cancelled
        }
        if let urlError = error as? URLError {
            return .transport(urlError)
        }
        return .transport(URLError(.unknown))
    }

    func requestData(_ requestType: RequestType, path: String, responseType: ResponseType) async throws -> (Data, HTTPURLResponse) {
        let request = URLRequest(url: try composedURL(with: path), requestType: requestType, contentType: nil, responseType: responseType, authorizationHeaderValue: authorizationHeaderValue, token: token, authorizationHeaderKey: authorizationHeaderKey, headerFields: headerFields)

        // Route through the interceptor chain so retry/auth-refresh apply to downloads too. Caching is the
        // caller's job (handleDataRequest/handleImageRequest write under the real cacheName) — writing here
        // too would double-write under nil and orphan a file when a cacheName is given.
        let exchange = try await perform(request)
        return (exchange.data, exchange.response)
    }

    func cancelRequest(_ sessionTaskType: SessionTaskType, requestType: RequestType, url: URL) async {
        let (dataTasks, uploadTasks, downloadTasks) = await session.tasks
        var sessionTasks = [URLSessionTask]()
        switch sessionTaskType {
        case .data:
            sessionTasks = dataTasks
        case .download:
            sessionTasks = downloadTasks
        case .upload:
            sessionTasks = uploadTasks
        }

        for sessionTask in sessionTasks {
            if sessionTask.originalRequest?.httpMethod == requestType.rawValue && sessionTask.originalRequest?.url?.absoluteString == url.absoluteString {
                sessionTask.cancel()
                break
            }
        }
    }

    nonisolated func cacheOrPurgeData(data: Data?, path: String, cacheName: String?, cachingLevel: CachingLevel) throws {
        try cacheStore.storeData(data, forResource: cacheResource(for: path, cacheName: cacheName), level: cachingLevel)
    }

    @discardableResult
    nonisolated func cacheOrPurgeImage(data: Data?, path: String, cacheName: String?, cachingLevel: CachingLevel) throws -> Image? {
        try cacheStore.storeImage(data: data, forResource: cacheResource(for: path, cacheName: cacheName), level: cachingLevel)
    }
}
