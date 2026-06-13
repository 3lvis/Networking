import Foundation

extension Networking {
    func objectFromCache(for path: String, cacheName: String?, cachingLevel: CachingLevel, responseType: ResponseType) throws -> Any? {
        /// Workaround: Remove URL parameters from path. That can lead to writing cached files with names longer than
        /// 255 characters, resulting in error. Another option to explore is to use a hash version of the url if it's
        /// longer than 255 characters.
        let destinationURL = try destinationURL(for: path, cacheName: cacheName)

        switch cachingLevel {
        case .memory:
            try FileManager.default.remove(at: destinationURL)
            return cache.object(forKey: destinationURL.absoluteString as AnyObject)
        case .memoryAndFile:
            if let object = cache.object(forKey: destinationURL.absoluteString as AnyObject) {
                return object
            } else if FileManager.default.exists(at: destinationURL) {
                var returnedObject: Any?

                let object = destinationURL.getData()
                if responseType == .image {
                    returnedObject = Image(data: object)
                } else {
                    returnedObject = object
                }
                if let returnedObject = returnedObject {
                    cache.setObject(returnedObject as AnyObject, forKey: destinationURL.absoluteString as AnyObject)
                }

                return returnedObject
            } else {
                return nil
            }
        case .none:
            cache.removeObject(forKey: destinationURL.absoluteString as AnyObject)
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
        // Store the file's raw bytes as the fake response; the async fake path serves Data as-is.
        registerFake(requestType: requestType, path: path, headerFields: nil, response: data, responseType: .json, statusCode: statusCode, delay: delay)
    }

    func registerFake(requestType: RequestType, path: String, headerFields: [String: String]?, response: Any?, responseType: ResponseType, statusCode: Int, delay: Double) {
        var requests = fakeRequests[requestType] ?? [String: FakeRequest]()
        requests[path] = FakeRequest(response: response, responseType: responseType, headerFields: headerFields, statusCode: statusCode, delay: delay)
        fakeRequests[requestType] = requests
    }

    func handleFakeRequest(_ fakeRequest: FakeRequest, path: String, cacheName: String?, cachingLevel: CachingLevel) throws -> (Any?, HTTPURLResponse, NSError?) {
        var error: NSError?
        let url = try composedURL(with: path)
        let response = HTTPURLResponse(url: url, headerFields: fakeRequest.headerFields, statusCode: fakeRequest.statusCode)

        if let unauthorizedRequestCallback = unauthorizedRequestCallback, fakeRequest.statusCode == 403 || fakeRequest.statusCode == 401 {
            unauthorizedRequestCallback()
        }

        if fakeRequest.statusCode.statusCodeType != .successful {
            error = NSError(statusCode: fakeRequest.statusCode)
        }

        switch fakeRequest.responseType {
        case .image:
            try cacheOrPurgeImage(data: fakeRequest.response as? Data, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
        case .data:
            try cacheOrPurgeData(data: fakeRequest.response as? Data, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
        case .json:
            try cacheOrPurgeJSON(object: fakeRequest.response, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
        }
        return (fakeRequest.response, response, error)
    }


    func handleDataRequest<T: DataDownloadable>(_ requestType: RequestType, path: String, cacheName: String?, cachingLevel: CachingLevel, responseType: ResponseType) async -> Result<T, NetworkingError> {
        do {
            let data: Data
            let response: HTTPURLResponse
            if let fakeRequests = fakeRequests[requestType], let fakeRequest = fakeRequests[path] {
                let (_, fakeResponse, _) = try handleFakeRequest(fakeRequest, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
                if fakeRequest.delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(fakeRequest.delay * 1_000_000_000))
                }
                guard fakeResponse.statusCode.statusCodeType == .successful else {
                    return .failure(downloadError(forStatusCode: fakeResponse.statusCode))
                }
                guard let fakeData = fakeRequest.response as? Data else { return .failure(.invalidResponse) }
                data = fakeData
                response = fakeResponse
            } else if let cached = try objectFromCache(for: path, cacheName: cacheName, cachingLevel: cachingLevel, responseType: responseType) as? Data {
                data = cached
                response = HTTPURLResponse(url: try composedURL(with: path), statusCode: 200)
            } else {
                let (downloaded, networkResponse) = try await requestData(requestType, path: path, cachingLevel: cachingLevel, responseType: responseType)
                try cacheOrPurgeData(data: downloaded, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
                guard networkResponse.statusCode.statusCodeType == .successful else {
                    return .failure(downloadError(forStatusCode: networkResponse.statusCode))
                }
                data = downloaded
                response = networkResponse
            }
            return .success(T.makeDownloadResult(data: data, statusCode: response.statusCode, headers: headerFields(from: response)))
        } catch {
            return .failure(downloadError(error))
        }
    }

    func handleImageRequest<T: ImageDownloadable>(_ requestType: RequestType, path: String, cacheName: String?, cachingLevel: CachingLevel, responseType: ResponseType) async -> Result<T, NetworkingError> {
        do {
            let image: Image
            let response: HTTPURLResponse
            if let fakeRequests = fakeRequests[requestType], let fakeRequest = fakeRequests[path] {
                let (_, fakeResponse, _) = try handleFakeRequest(fakeRequest, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
                if fakeRequest.delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(fakeRequest.delay * 1_000_000_000))
                }
                guard fakeResponse.statusCode.statusCodeType == .successful else {
                    return .failure(downloadError(forStatusCode: fakeResponse.statusCode))
                }
                guard let fakeImage = fakeRequest.response as? Image else { return .failure(.invalidResponse) }
                image = fakeImage
                response = fakeResponse
            } else if let cached = try objectFromCache(for: path, cacheName: cacheName, cachingLevel: cachingLevel, responseType: responseType) as? Image {
                image = cached
                response = HTTPURLResponse(url: try composedURL(with: path), statusCode: 200)
            } else {
                let (data, networkResponse) = try await requestData(requestType, path: path, cachingLevel: cachingLevel, responseType: responseType)
                guard networkResponse.statusCode.statusCodeType == .successful else {
                    return .failure(downloadError(forStatusCode: networkResponse.statusCode))
                }
                guard let downloaded = try cacheOrPurgeImage(data: data, path: path, cacheName: cacheName, cachingLevel: cachingLevel) else {
                    return .failure(.invalidResponse)
                }
                image = downloaded
                response = networkResponse
            }
            return .success(T.makeDownloadResult(image: image, statusCode: response.statusCode, headers: headerFields(from: response)))
        } catch {
            return .failure(downloadError(error))
        }
    }

    private func headerFields(from response: HTTPURLResponse) -> [String: AnyCodable] {
        Dictionary(uniqueKeysWithValues: response.allHeaderFields.compactMap { key, value in
            (key as? String).map { ($0, AnyCodable(value)) }
        })
    }

    private func downloadError(forStatusCode statusCode: Int) -> NetworkingError {
        let message = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        switch statusCode.statusCodeType {
        case .clientError: return .clientError(statusCode: statusCode, message: message)
        case .serverError: return .serverError(statusCode: statusCode, message: message, details: nil)
        default: return .unexpectedError(statusCode: statusCode, message: message)
        }
    }

    private func downloadError(_ error: Error) -> NetworkingError {
        if error is CancellationError || (error as? URLError)?.code == .cancelled {
            return .cancelled
        }
        return .unexpectedError(statusCode: nil, message: "Failed to process request (error: \(error.localizedDescription)).")
    }

    func requestData(_ requestType: RequestType, path: String, cachingLevel: CachingLevel, responseType: ResponseType) async throws -> (Data, HTTPURLResponse) {
        let request = URLRequest(url: try composedURL(with: path), requestType: requestType, path: path, parameterType: nil, responseType: responseType, boundary: boundary, authorizationHeaderValue: authorizationHeaderValue, token: token, authorizationHeaderKey: authorizationHeaderKey, headerFields: headerFields)

        let (data, response) = try await self.session.data(for: request)

        var returnedResponse: URLResponse?
        var returnedData: Data?

        returnedResponse = response
        returnedData = data

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                returnedData = data
            } else {
                if let unauthorizedRequestCallback = self.unauthorizedRequestCallback, httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
                    unauthorizedRequestCallback()
                }
            }

            try self.cacheOrPurgeData(data: data, path: path, cacheName: nil, cachingLevel: cachingLevel)

            self.logError(parameterType: nil, parameters: nil, data: returnedData, request: request, response: returnedResponse, error: nil)
            return (data, httpResponse)
        } else {
            let url = try self.composedURL(with: path)
            let response = HTTPURLResponse(url: url, statusCode: 400)
            return (data, response)
        }
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

    func logError(parameterType: ParameterType?, parameters: Any? = nil, data: Data?, request: URLRequest?, response: URLResponse?, error: NSError?) {
        guard isErrorLoggingEnabled else { return }
        guard let error = error else { return }

        print(" ")
        print("========== Networking Error ==========")
        print(" ")

        let isCancelled = error.code == NSURLErrorCancelled
        if isCancelled {
            if let request = request, let url = request.url {
                print("Cancelled request: \(url.absoluteString)")
                print(" ")
            }
        } else {
            print("*** Request ***")
            print(" ")

            print("Error \(error.code): \(error.description)")
            print(" ")

            if let request = request, let url = request.url {
                print("URL: \(url.absoluteString)")
                print(" ")
            }

            if let headers = request?.allHTTPHeaderFields {
                print("Headers: \(headers)")
                print(" ")
            }

            if let parameterType = parameterType, let parameters = parameters {
                switch parameterType {
                case .json:
                    do {
                        let data = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
                        let string = String(data: data, encoding: .utf8)
                        if let string = string {
                            print("Parameters: \(string)")
                            print(" ")
                        }
                    } catch let error as NSError {
                        print("Failed pretty printing parameters: \(parameters), error: \(error)")
                        print(" ")
                    }
                case .formURLEncoded:
                    guard let parametersDictionary = parameters as? [String: Any] else { fatalError("Couldn't cast parameters as dictionary: \(parameters)") }
                    do {
                        let formattedParameters = try parametersDictionary.urlEncodedString()
                        print("Parameters: \(formattedParameters)")
                    } catch let error as NSError {
                        print("Failed parsing Parameters: \(parametersDictionary) — \(error)")
                    }
                    print(" ")
                default: break
                }
            }

            if let data = data, let stringData = String(data: data, encoding: .utf8) {
                print("Data: \(stringData)")
                print(" ")
            }

            if let response = response as? HTTPURLResponse {
                print("*** Response ***")
                print(" ")

                print("Headers: \(response.allHeaderFields)")
                print(" ")

                print("Status code: \(response.statusCode) — \(HTTPURLResponse.localizedString(forStatusCode: response.statusCode))")
                print(" ")
            }
        }
        print("================= ~ ==================")
        print(" ")
    }

    func cacheOrPurgeJSON(object: Any?, path: String, cacheName: String?, cachingLevel: CachingLevel) throws {
        let destinationURL = try self.destinationURL(for: path, cacheName: cacheName)

        if let unwrappedObject = object {
            switch cachingLevel {
            case .memory:
                self.cache.setObject(unwrappedObject as AnyObject, forKey: destinationURL.absoluteString as AnyObject)
            case .memoryAndFile:

                let convertedData = try JSONSerialization.data(withJSONObject: unwrappedObject, options: [])
                _ = try convertedData.write(to: destinationURL, options: [.atomic])
                self.cache.setObject(unwrappedObject as AnyObject, forKey: destinationURL.absoluteString as AnyObject)
            case .none:
                break
            }
        } else {
            self.cache.removeObject(forKey: destinationURL.absoluteString as AnyObject)
        }
    }

    func cacheOrPurgeData(data: Data?, path: String, cacheName: String?, cachingLevel: CachingLevel) throws {
        let destinationURL = try self.destinationURL(for: path, cacheName: cacheName)

        if let returnedData = data, returnedData.count > 0 {
            switch cachingLevel {
            case .memory:
                self.cache.setObject(returnedData as AnyObject, forKey: destinationURL.absoluteString as AnyObject)
            case .memoryAndFile:
                _ = try returnedData.write(to: destinationURL, options: [.atomic])
                self.cache.setObject(returnedData as AnyObject, forKey: destinationURL.absoluteString as AnyObject)
            case .none:
                break
            }
        } else {
            self.cache.removeObject(forKey: destinationURL.absoluteString as AnyObject)
        }
    }
    
    @discardableResult
    func cacheOrPurgeImage(data: Data?, path: String, cacheName: String?, cachingLevel: CachingLevel) throws -> Image? {
        let destinationURL = try self.destinationURL(for: path, cacheName: cacheName)

        var image: Image?
        if let data = data, let nonOptionalImage = Image(data: data), data.count > 0 {
            switch cachingLevel {
            case .memory:
                self.cache.setObject(nonOptionalImage, forKey: destinationURL.absoluteString as AnyObject)
            case .memoryAndFile:
                _ = try data.write(to: destinationURL, options: [.atomic])
                self.cache.setObject(nonOptionalImage, forKey: destinationURL.absoluteString as AnyObject)
            case .none:
                break
            }
            image = nonOptionalImage
        } else {
            self.cache.removeObject(forKey: destinationURL.absoluteString as AnyObject)
        }

        return image
    }
}
