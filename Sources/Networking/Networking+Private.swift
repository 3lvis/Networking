import Foundation

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
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
        do {
            if let result = try FileManager.json(from: fileName, bundle: bundle) {
                registerFake(requestType: requestType, path: path, headerFields: nil, response: result, responseType: .json, statusCode: statusCode, delay: delay)
            }
        } catch ParsingError.notFound {
            fatalError("We couldn't find \(fileName), are you sure is there?")
        } catch {
            fatalError("Converting data to JSON failed")
        }
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

    func handleJSONRequest(_ requestType: RequestType, path: String, cacheName: String?, parameterType: ParameterType?, parameters: Any?, parts: [FormDataPart]? = nil, responseType: ResponseType, cachingLevel: CachingLevel) async throws -> JSONResult {

        if let fakeRequest = try FakeRequest.find(ofType: requestType, forPath: path, in: fakeRequests) {
            let (_, response, error) = try handleFakeRequest(fakeRequest, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
            if fakeRequest.delay > 0 {
                let nanoseconds = UInt64(fakeRequest.delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            return try JSONResult(body: fakeRequest.response, response: response, error: error)
        } else {
            switch cachingLevel {
            case .memory, .memoryAndFile:
                if let object = try objectFromCache(for: path, cacheName: nil, cachingLevel: cachingLevel, responseType: responseType) {
                    let url = try self.composedURL(with: path)
                    let response = HTTPURLResponse(url: url, statusCode: 200)
                    return try JSONResult(body: object, response: response, error: nil)
                }
            default: break
            }

            let (data, response) = try await requestData(requestType, path: path, cachingLevel: cachingLevel, parameterType: parameterType, parameters: parameters, parts: parts, responseType: responseType)
            var responseError: NSError?
            if response.statusCode.statusCodeType != .successful {
                responseError = NSError(statusCode: response.statusCode)
            }
            return try JSONResult(body: data, response: response, error: responseError)
        }
    }

    func handleDataRequest(_ requestType: RequestType, path: String, cacheName: String?, cachingLevel: CachingLevel, responseType: ResponseType) async throws -> DataResult {
        if let fakeRequests = fakeRequests[requestType], let fakeRequest = fakeRequests[path] {
            let (_, response, error) = try handleFakeRequest(fakeRequest, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
            if fakeRequest.delay > 0 {
                let nanoseconds = UInt64(fakeRequest.delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            return DataResult(body: fakeRequest.response, response: response, error: error)
        } else {
            let object = try objectFromCache(for: path, cacheName: cacheName, cachingLevel: cachingLevel, responseType: responseType)
            if let object = object {
                let url = try self.composedURL(with: path)
                let response = HTTPURLResponse(url: url, statusCode: 200)
                return DataResult(body: object, response: response, error: nil)
            } else {
                let (data, response) = try await requestData(requestType, path: path, cachingLevel: cachingLevel, parameterType: nil, parameters: nil, parts: nil, responseType: responseType)
                try self.cacheOrPurgeData(data: data, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
                var responseError: NSError?
                if response.statusCode.statusCodeType != .successful {
                    responseError = NSError(statusCode: response.statusCode)
                }
                return DataResult(body: data, response: response, error: responseError)
            }
        }
    }

    func handleImageRequest(_ requestType: RequestType, path: String, cacheName: String?, cachingLevel: CachingLevel, responseType: ResponseType) async throws -> ImageResult {
        if let fakeRequests = fakeRequests[requestType], let fakeRequest = fakeRequests[path] {
            let (_, response, error) = try handleFakeRequest(fakeRequest, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
            if fakeRequest.delay > 0 {
                let nanoseconds = UInt64(fakeRequest.delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            return ImageResult(body: fakeRequest.response, response: response, error: error)
        } else {
            let object = try objectFromCache(for: path, cacheName: cacheName, cachingLevel: cachingLevel, responseType: responseType)
            if let object = object {
                let url = try self.composedURL(with: path)
                let response = HTTPURLResponse(url: url, statusCode: 200)
                return ImageResult(body: object, response: response, error: nil)
            } else {
                let (data, response) = try await requestData(requestType, path: path, cachingLevel: cachingLevel, parameterType: nil, parameters: nil, parts: nil, responseType: responseType)
                let returnedImage = try self.cacheOrPurgeImage(data: data, path: path, cacheName: cacheName, cachingLevel: cachingLevel)
                var responseError: NSError?
                if response.statusCode.statusCodeType != .successful {
                    responseError = NSError(statusCode: response.statusCode)
                }
                return ImageResult(body: returnedImage, response: response, error: responseError)
            }
        }
    }

    func requestData(_ requestType: RequestType, path: String, cachingLevel: CachingLevel, parameterType: ParameterType?, parameters: Any?, parts: [FormDataPart]?, responseType: ResponseType) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: try composedURL(with: path), requestType: requestType, path: path, parameterType: parameterType, responseType: responseType, boundary: boundary, authorizationHeaderValue: authorizationHeaderValue, token: token, authorizationHeaderKey: authorizationHeaderKey, headerFields: headerFields)

        if let parameterType = parameterType {
            switch parameterType {
            case .none: break
            case .json:
                if let parameters = parameters {
                    request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
                }
            case .formURLEncoded:
                guard let parametersDictionary = parameters as? [String: Any] else { fatalError("Couldn't convert parameters to a dictionary: \(String(describing: parameters))") }

                let formattedParameters = try parametersDictionary.urlEncodedString()
                switch requestType {
                case .get, .delete:
                    let urlEncodedPath: String
                    if path.contains("?") {
                        if let lastCharacter = path.last, lastCharacter == "?" {
                            urlEncodedPath = path + formattedParameters
                        } else {
                            urlEncodedPath = path + "&" + formattedParameters
                        }
                    } else {
                        urlEncodedPath = path + "?" + formattedParameters
                    }
                    request.url = try composedURL(with: urlEncodedPath)
                case .post, .put, .patch:
                    request.httpBody = formattedParameters.data(using: .utf8)
                }

            case .multipartFormData:
                var bodyData = Data()

                if let parameters = parameters as? [String: Any] {
                    for (key, value) in parameters {
                        let usedValue: Any = value is NSNull ? "null" : value
                        var body = ""
                        body += "--\(boundary)\r\n"
                        body += "Content-Disposition: form-data; name=\"\(key)\""
                        body += "\r\n\r\n\(usedValue)\r\n"
                        bodyData.append(body.data(using: .utf8)!)
                    }
                }

                if let parts = parts {
                    for var part in parts {
                        part.boundary = boundary
                        bodyData.append(part.formData as Data)
                    }
                }

                bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
                request.httpBody = bodyData as Data
            case .custom:
                request.httpBody = parameters as? Data
            }
        }

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

            self.logError(parameterType: parameterType, parameters: parameters, data: returnedData, request: request, response: returnedResponse, error: nil)
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
