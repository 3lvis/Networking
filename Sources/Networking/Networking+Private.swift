import Foundation

extension Networking {
    nonisolated func objectFromCache(for path: String, cacheName: String?, cachingLevel: CachingLevel, responseType: ResponseType) throws -> Any? {
        let destinationURL = try destinationURL(for: path, cacheName: cacheName)

        let key = destinationURL.absoluteString
        switch cachingLevel {
        case .memory:
            try FileManager.default.remove(at: destinationURL)
            return cache.object(forKey: key as AnyObject)
        case .memoryAndFile:
            // Memory is the warm tier — a memory hit is served without touching the disk (the NSCache
            // absorbs repeat reads, so the file's mtime is only re-warmed on a memory miss, below).
            if let object = cache.object(forKey: key as AnyObject) {
                return object
            } else if FileManager.default.exists(at: destinationURL) {
                let fileDate = try? destinationURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                if cacheExpiry.isExpired(fileDate: fileDate) {
                    try FileManager.default.remove(at: destinationURL)
                    return nil
                }

                let returnedObject: Any? = responseType == .image ? Image(data: destinationURL.getData()) : destinationURL.getData()
                if let returnedObject {
                    cache.setObject(returnedObject as AnyObject, forKey: key as AnyObject)
                    // Re-warm: bump the file's mtime so an entry in active use never expires. Only happens
                    // on a memory miss, so it's ~once per entry per launch — no explicit debounce needed.
                    try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: destinationURL.path)
                }

                return returnedObject
            } else {
                return nil
            }
        case .none:
            cache.removeObject(forKey: key as AnyObject)
            try FileManager.default.remove(at: destinationURL)
            return nil
        }
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

        if fakeRequest.statusCode.statusCodeType != .successful {
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


    func handleDataRequest<T: DataDownloadable>(_ requestType: RequestType, path: String, cacheName: String?, cachingLevel: CachingLevel, responseType: ResponseType) async -> Result<T, NetworkingError> {
        let requestID = UUID()
        let clock = ContinuousClock()
        let startInstant = clock.now
        let context = RequestContext(id: requestID, requestType: requestType, url: try? composedURL(with: path), headers: headerFields)
        emit(.started(context))

        let result: Result<T, NetworkingError>
        var statusCode: Int?
        var byteCount = 0
        do {
            if let fakeRequests = fakeRequests[requestType], let fakeRequest = fakeRequests[path] {
                let (fakeResponse, _) = try handleFakeRequest(fakeRequest, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
                if fakeRequest.delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(fakeRequest.delay * 1_000_000_000))
                }
                statusCode = fakeResponse.statusCode
                if fakeResponse.statusCode.statusCodeType != .successful {
                    result = .failure(downloadError(forStatusCode: fakeResponse.statusCode))
                } else if case let .data(fakeData) = fakeRequest.payload {
                    byteCount = fakeData.count
                    result = .success(T.makeDownloadResult(data: fakeData, statusCode: fakeResponse.statusCode, headers: headerFields(from: fakeResponse)))
                } else {
                    result = .failure(.invalidResponse)
                }
            } else if let cached = try objectFromCache(for: path, cacheName: cacheName, cachingLevel: cachingLevel, responseType: responseType) as? Data {
                let response = HTTPURLResponse(url: try composedURL(with: path), statusCode: 200)
                statusCode = 200
                result = .success(T.makeDownloadResult(data: cached, statusCode: 200, headers: headerFields(from: response)))
            } else {
                let (downloaded, networkResponse) = try await requestData(requestType, path: path, cachingLevel: cachingLevel, responseType: responseType)
                try cacheOrPurgeData(data: downloaded, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
                statusCode = networkResponse.statusCode
                if networkResponse.statusCode.statusCodeType != .successful {
                    result = .failure(downloadError(forStatusCode: networkResponse.statusCode))
                } else {
                    byteCount = downloaded.count
                    result = .success(T.makeDownloadResult(data: downloaded, statusCode: networkResponse.statusCode, headers: headerFields(from: networkResponse)))
                }
            }
        } catch {
            result = .failure(downloadError(error))
        }
        return complete(result, context: context, statusCode: statusCode, byteCount: byteCount, metrics: nil, duration: clock.now - startInstant)
    }

    func handleImageRequest<T: ImageDownloadable>(_ requestType: RequestType, path: String, cacheName: String?, cachingLevel: CachingLevel, responseType: ResponseType) async -> Result<T, NetworkingError> {
        let requestID = UUID()
        let clock = ContinuousClock()
        let startInstant = clock.now
        let context = RequestContext(id: requestID, requestType: requestType, url: try? composedURL(with: path), headers: headerFields)
        emit(.started(context))

        let result: Result<T, NetworkingError>
        var statusCode: Int?
        var byteCount = 0
        do {
            if let fakeRequests = fakeRequests[requestType], let fakeRequest = fakeRequests[path] {
                let (fakeResponse, _) = try handleFakeRequest(fakeRequest, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
                if fakeRequest.delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(fakeRequest.delay * 1_000_000_000))
                }
                statusCode = fakeResponse.statusCode
                if fakeResponse.statusCode.statusCodeType != .successful {
                    result = .failure(downloadError(forStatusCode: fakeResponse.statusCode))
                } else if case let .image(fakeImage) = fakeRequest.payload {
                    result = .success(T.makeDownloadResult(image: fakeImage, statusCode: fakeResponse.statusCode, headers: headerFields(from: fakeResponse)))
                } else {
                    result = .failure(.invalidResponse)
                }
            } else if let cached = try objectFromCache(for: path, cacheName: cacheName, cachingLevel: cachingLevel, responseType: responseType) as? Image {
                let response = HTTPURLResponse(url: try composedURL(with: path), statusCode: 200)
                statusCode = 200
                result = .success(T.makeDownloadResult(image: cached, statusCode: 200, headers: headerFields(from: response)))
            } else {
                let (data, networkResponse) = try await requestData(requestType, path: path, cachingLevel: cachingLevel, responseType: responseType)
                statusCode = networkResponse.statusCode
                if networkResponse.statusCode.statusCodeType != .successful {
                    result = .failure(downloadError(forStatusCode: networkResponse.statusCode))
                } else if let downloaded = try cacheOrPurgeImage(data: data, path: path, cacheName: cacheName, cachingLevel: cachingLevel) {
                    byteCount = data.count
                    result = .success(T.makeDownloadResult(image: downloaded, statusCode: networkResponse.statusCode, headers: headerFields(from: networkResponse)))
                } else {
                    result = .failure(.invalidResponse)
                }
            }
        } catch {
            result = .failure(downloadError(error))
        }
        return complete(result, context: context, statusCode: statusCode, byteCount: byteCount, metrics: nil, duration: clock.now - startInstant)
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

    func requestData(_ requestType: RequestType, path: String, cachingLevel: CachingLevel, responseType: ResponseType) async throws -> (Data, HTTPURLResponse) {
        let request = URLRequest(url: try composedURL(with: path), requestType: requestType, contentType: nil, responseType: responseType, authorizationHeaderValue: authorizationHeaderValue, token: token, authorizationHeaderKey: authorizationHeaderKey, headerFields: headerFields)

        // Route through the interceptor chain so retry/auth-refresh apply to downloads too.
        let exchange = try await perform(request)
        try self.cacheOrPurgeData(data: exchange.data, path: path, cacheName: nil, cachingLevel: cachingLevel)
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
        let destinationURL = try self.destinationURL(for: path, cacheName: cacheName)
        let key = destinationURL.absoluteString

        if let returnedData = data, returnedData.count > 0 {
            switch cachingLevel {
            case .memory:
                self.cache.setObject(returnedData as AnyObject, forKey: key as AnyObject)
            case .memoryAndFile:
                _ = try returnedData.write(to: destinationURL, options: [.atomic])
                self.cache.setObject(returnedData as AnyObject, forKey: key as AnyObject)
            case .none:
                break
            }
            // The disk write itself sets a fresh mtime — that *is* the entry's last-use timestamp.
        } else {
            self.cache.removeObject(forKey: key as AnyObject)
        }
    }

    @discardableResult
    nonisolated func cacheOrPurgeImage(data: Data?, path: String, cacheName: String?, cachingLevel: CachingLevel) throws -> Image? {
        let destinationURL = try self.destinationURL(for: path, cacheName: cacheName)
        let key = destinationURL.absoluteString

        var image: Image?
        if let data = data, let nonOptionalImage = Image(data: data), data.count > 0 {
            switch cachingLevel {
            case .memory:
                self.cache.setObject(nonOptionalImage, forKey: key as AnyObject)
            case .memoryAndFile:
                _ = try data.write(to: destinationURL, options: [.atomic])
                self.cache.setObject(nonOptionalImage, forKey: key as AnyObject)
            case .none:
                break
            }
            image = nonOptionalImage
        } else {
            self.cache.removeObject(forKey: key as AnyObject)
        }

        return image
    }
}
