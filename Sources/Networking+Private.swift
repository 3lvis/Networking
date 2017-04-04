import Foundation

extension Networking {

    func objectFromCache(for path: String, cacheName: String?, responseType: ResponseType) -> Any? {
        /// Workaround: Remove URL parameters from path. That can lead to writing cached files with names longer than
        /// 255 characters, resulting in error. Another option to explore is to use a hash version of the url if it's
        /// longer than 255 characters.
        guard let destinationURL = try? destinationURL(for: path, cacheName: cacheName) else { fatalError("Couldn't get destination URL for path: \(path) and cacheName: \(String(describing: cacheName))") }

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
    }

    func registerFake(requestType: RequestType, path: String, fileName: String, bundle: Bundle) {
        do {
            if let result = try JSON.from(fileName, bundle: bundle) {
                registerFake(requestType: requestType, path: path, response: result, responseType: .json, statusCode: 200)
            }
        } catch ParsingError.notFound {
            fatalError("We couldn't find \(fileName), are you sure is there?")
        } catch {
            fatalError("Converting data to JSON failed")
        }
    }

    func registerFake(requestType: RequestType, path: String, response: Any?, responseType: ResponseType, statusCode: Int) {
        var requests = fakeRequests[requestType] ?? [String: FakeRequest]()
        requests[path] = FakeRequest(response: response, responseType: responseType, statusCode: statusCode)
        fakeRequests[requestType] = requests
    }

    func requestJSON(requestType: RequestType, path: String, cacheName: String?, parameterType: ParameterType?, parameters: Any?, parts: [FormDataPart]?, completion: @escaping (_ result: JSONResult) -> Void) -> String {
        return request(requestType, path: path, cacheName: cacheName, parameterType: parameterType, parameters: parameters, parts: parts, responseType: .json) { deserialized, response, error in
            completion(JSONResult(body: deserialized, response: response, error: error))
        }
    }

    func requestImage(path: String, cacheName: String?, completion: @escaping (_ result: ImageResult) -> Void) -> String {
        return request(.get, path: path, cacheName: cacheName, parameterType: nil, parameters: nil, parts: nil, responseType: .image) { deserialized, response, error in
            completion(ImageResult(body: deserialized, response: response, error: error))
        }
    }

    func requestData(path: String, cacheName: String?, completion: @escaping (_ result: DataResult) -> Void) -> String {
        return request(.get, path: path, cacheName: cacheName, parameterType: nil, parameters: nil, parts: nil, responseType: .data) { deserialized, response, error in
            completion(DataResult(body: deserialized, response: response, error: error))
        }
    }

    func request(_ requestType: RequestType, path: String, cacheName: String?, parameterType: ParameterType?, parameters: Any?, parts: [FormDataPart]?, responseType: ResponseType, completion: @escaping (_ response: Any?, _ response: HTTPURLResponse, _ error: NSError?) -> Void) -> String {
        if let fakeRequests = fakeRequests[requestType], let fakeRequest = fakeRequests[path] {
            return handleFakeRequest(fakeRequest, requestType: requestType, path: path, cacheName: cacheName, parameterType: parameterType, parameters: parameters, parts: parts, responseType: responseType, completion: completion)
        } else {
            switch responseType {
            case .json:
                return handleJSONRequest(requestType, path: path, cacheName: cacheName, parameterType: parameterType, parameters: parameters, parts: parts, responseType: responseType, completion: completion)
            case .data, .image:
                return handleDataOrImageRequest(requestType, path: path, cacheName: cacheName, parameterType: parameterType, parameters: parameters, parts: parts, responseType: responseType, completion: completion)
            }
        }
    }

    func handleFakeRequest(_ fakeRequest: FakeRequest, requestType: RequestType, path: String, cacheName: String?, parameterType: ParameterType?, parameters: Any?, parts: [FormDataPart]?, responseType: ResponseType, completion: @escaping (_ response: Any?, _ response: HTTPURLResponse, _ error: NSError?) -> Void) -> String {
        let requestID = UUID().uuidString

        if fakeRequest.statusCode.statusCodeType == .successful {
            let url = try! self.composedURL(with: path)
            let response = HTTPURLResponse(url: url, statusCode: fakeRequest.statusCode)
            TestCheck.testBlock(self.isSynchronous) {
                completion(fakeRequest.response, response, nil)
            }
        } else {
            if let unauthorizedRequestCallback = unauthorizedRequestCallback, fakeRequest.statusCode == 403 || fakeRequest.statusCode == 401 {
                TestCheck.testBlock(self.isSynchronous) {
                    unauthorizedRequestCallback()
                }
            } else {
                let url = try! self.composedURL(with: path)
                let error = NSError(fakeRequest: fakeRequest)
                let response = HTTPURLResponse(url: url, statusCode: fakeRequest.statusCode)
                TestCheck.testBlock(self.isSynchronous) {
                    completion(fakeRequest.response, response, error)
                }
            }
        }

        return requestID
    }

    func handleJSONRequest(_ requestType: RequestType, path: String, cacheName: String?, parameterType: ParameterType?, parameters: Any?, parts: [FormDataPart]?, responseType: ResponseType, completion: @escaping (_ response: Any?, _ response: HTTPURLResponse, _ error: NSError?) -> Void) -> String {
        return dataRequest(requestType, path: path, cacheName: cacheName, parameterType: parameterType, parameters: parameters, parts: parts, responseType: responseType) { data, response, error in
            var returnedError = error
            var returnedResponse: Any?
            if let data = data, data.count > 0 {
                do {
                    returnedResponse = try JSONSerialization.jsonObject(with: data, options: [])
                } catch let JSONParsingError as NSError {
                    if returnedError == nil {
                        returnedError = JSONParsingError
                    }
                }
            }
            TestCheck.testBlock(self.isSynchronous) {
                completion(returnedResponse, response, returnedError)
            }
        }
    }

    func handleDataOrImageRequest(_ requestType: RequestType, path: String, cacheName: String?, parameterType: ParameterType?, parameters: Any?, parts: [FormDataPart]?, responseType: ResponseType, completion: @escaping (_ response: Any?, _ response: HTTPURLResponse, _ error: NSError?) -> Void) -> String {
        let object = objectFromCache(for: path, cacheName: cacheName, responseType: responseType)
        if let object = object {
            let requestID = UUID().uuidString

            TestCheck.testBlock(isSynchronous) {
                let url = try! self.composedURL(with: path)
                let response = HTTPURLResponse(url: url, statusCode: 200)
                completion(object, response, nil)
            }

            return requestID
        } else {
            return dataRequest(requestType, path: path, cacheName: cacheName, parameterType: parameterType, parameters: parameters, parts: parts, responseType: responseType) { data, response, error in

                var returnedResponse: Any?
                if let data = data, data.count > 0 {
                    guard let destinationURL = try? self.destinationURL(for: path, cacheName: cacheName) else { fatalError("Couldn't get destination URL for path: \(path) and cacheName: \(String(describing: cacheName))") }
                    _ = try? data.write(to: destinationURL, options: [.atomic])
                    switch responseType {
                    case .data:
                        self.cache.setObject(data as AnyObject, forKey: destinationURL.absoluteString as AnyObject)
                        returnedResponse = data
                    case .image:
                        if let image = Image(data: data) {
                            self.cache.setObject(image, forKey: destinationURL.absoluteString as AnyObject)
                            returnedResponse = image
                        }
                    default:
                        fatalError("Response Type is different than Data and Image")
                    }
                }
                TestCheck.testBlock(self.isSynchronous) {
                    completion(returnedResponse, response, error)
                }
            }
        }
    }

    func dataRequest(_ requestType: RequestType, path: String, cacheName: String?, parameterType: ParameterType?, parameters: Any?, parts: [FormDataPart]?, responseType: ResponseType, completion: @escaping (_ response: Data?, _ response: HTTPURLResponse, _ error: NSError?) -> Void) -> String {
        let requestID = UUID().uuidString
        var request = URLRequest(url: try! composedURL(with: path), requestType: requestType, path: path, parameterType: parameterType, responseType: responseType, boundary: boundary, authorizationHeaderValue: authorizationHeaderValue, token: token, authorizationHeaderKey: authorizationHeaderKey, headerFields: headerFields)

        DispatchQueue.main.async {
            NetworkActivityIndicator.sharedIndicator.visible = true
        }

        var serializingError: NSError?
        if let parameterType = parameterType {
            switch parameterType {
            case .none: break
            case .json:
                if let parameters = parameters {
                    do {
                        request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
                    } catch let error as NSError {
                        serializingError = error
                    }
                }
            case .formURLEncoded:
                guard let parametersDictionary = parameters as? [String: Any] else { fatalError("Couldn't convert parameters to a dictionary: \(String(describing: parameters))") }
                do {
                    let formattedParameters = try parametersDictionary.urlEncodedString()
                    switch requestType {
                    case .get, .delete:
                        let urlEncodedPath: String
                        if path.contains("?") {
                            if let lastCharacter = path.characters.last, lastCharacter == "?" {
                                urlEncodedPath = path + formattedParameters
                            } else {
                                urlEncodedPath = path + "&" + formattedParameters
                            }
                        } else {
                            urlEncodedPath = path + "?" + formattedParameters
                        }
                        request.url = try! composedURL(with: urlEncodedPath)
                    case .post, .put:
                        request.httpBody = formattedParameters.data(using: .utf8)
                    }
                } catch let error as NSError {
                    serializingError = error
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

        if let serializingError = serializingError {
            let url = try! self.composedURL(with: path)
            let response = HTTPURLResponse(url: url, statusCode: serializingError.code)
            completion(nil, response, serializingError)
        } else {
            var connectionError: Error?
            let semaphore = DispatchSemaphore(value: 0)
            var returnedResponse: URLResponse?
            var returnedData: Data?

            let session = self.session.dataTask(with: request) { data, response, error in
                returnedResponse = response
                connectionError = error
                returnedData = data

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                        if let data = data, data.count > 0 {
                            returnedData = data
                        }
                    } else {
                        var errorCode = httpResponse.statusCode
                        if let error = error as NSError? {
                            if error.code == URLError.cancelled.rawValue {
                                errorCode = error.code
                            }
                        }

                        connectionError = NSError(domain: Networking.domain, code: errorCode, userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)])
                    }
                }

                if TestCheck.isTesting && self.isSynchronous == false {
                    semaphore.signal()
                } else {
                    DispatchQueue.main.async {
                        NetworkActivityIndicator.sharedIndicator.visible = false
                    }

                    self.logError(parameterType: parameterType, parameters: parameters, data: returnedData, request: request, response: returnedResponse, error: connectionError as NSError?)
                    if let unauthorizedRequestCallback = self.unauthorizedRequestCallback, let error = connectionError as NSError?, error.code == 403 || error.code == 401 {
                        unauthorizedRequestCallback()
                    } else {
                        if let response = returnedResponse as? HTTPURLResponse {
                            completion(returnedData, response, connectionError as NSError?)
                        } else {
                            let url = try! self.composedURL(with: path)
                            let errorCode = (connectionError as NSError?)?.code ?? 200
                            let response = HTTPURLResponse(url: url, statusCode: errorCode)
                            completion(returnedData, response, connectionError as NSError?)
                        }
                    }
                }
            }

            session.taskDescription = requestID
            session.resume()

            if TestCheck.isTesting && isSynchronous == false {
                _ = semaphore.wait(timeout: DispatchTime.now() + 60.0)
                logError(parameterType: parameterType, parameters: parameters, data: returnedData, request: request as URLRequest, response: returnedResponse, error: connectionError as NSError?)
                if let unauthorizedRequestCallback = unauthorizedRequestCallback, let error = connectionError as NSError?, error.code == 403 || error.code == 401 {
                    unauthorizedRequestCallback()
                } else {
                    if let response = returnedResponse as? HTTPURLResponse {
                        completion(returnedData, response, connectionError as NSError?)
                    } else {
                        let url = try! self.composedURL(with: path)
                        let errorCode = (connectionError as NSError?)?.code ?? 200
                        let response = HTTPURLResponse(url: url, statusCode: errorCode)
                        completion(returnedData, response, connectionError as NSError?)
                    }
                }
            }
        }

        return requestID
    }

    func cancelRequest(_ sessionTaskType: SessionTaskType, requestType: RequestType, url: URL) {
        let semaphore = DispatchSemaphore(value: 0)
        session.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
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

            semaphore.signal()
        }

        _ = semaphore.wait(timeout: DispatchTime.now() + 60.0)
    }

    func logError(parameterType: ParameterType?, parameters: Any? = nil, data: Data?, request: URLRequest?, response: URLResponse?, error: NSError?) {
        if disableErrorLogging { return }
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
}
