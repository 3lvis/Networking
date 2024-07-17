import Foundation

extension Networking {
    func handle<T: Decodable>(_ requestType: RequestType, path: String, parameters: Any?) async -> Result<T, NetworkingError> {
        do {
            logger.info("Starting \(requestType.rawValue) request to \(path, privacy: .public)")

            if let fakeRequest = try FakeRequest.find(ofType: requestType, forPath: path, in: fakeRequests) {
                let (_, response, error) = try handleFakeRequest(fakeRequest, path: path, cacheName: nil, cachingLevel: .none)
                if fakeRequest.delay > 0 {
                    let nanoseconds = UInt64(fakeRequest.delay * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: nanoseconds)
                }
                let result = try JSONResult(body: fakeRequest.response, response: response, error: error)
                switch result {
                case .success(let response):
                    let decodedResponse = try JSONDecoder().decode(T.self, from: response.data)
                    logger.info("Successfully decoded response from fake request to \(path, privacy: .public)")
                    return .success(decodedResponse)
                case .failure(let response):
                    logger.error("Failed to process fake request to \(path, privacy: .public): \(response.error.localizedDescription, privacy: .public)")
                    return .failure(.unexpectedError(statusCode: nil, message: "Failed to process fake request (error: \(response.error.localizedDescription))."))
                }
            }

            let parameterType: Networking.ParameterType? = parameters != nil ? .json : nil
            var request = URLRequest(url: try composedURL(with: path), requestType: requestType, path: path, parameterType: parameterType, responseType: .json, boundary: boundary, authorizationHeaderValue: authorizationHeaderValue, token: token, authorizationHeaderKey: authorizationHeaderKey, headerFields: headerFields)

            if let parameters = parameters {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
            }

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response received from \(path, privacy: .public)")
                return .failure(.invalidResponse)
            }

            let statusCode = httpResponse.statusCode
            switch statusCode.statusCodeType {
            case .informational, .successful:
                logger.info("Received successful response with status code \(statusCode) from \(path, privacy: .public)")
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let decodedResponse = try decoder.decode(T.self, from: data)
                logger.info("Successfully decoded response from \(path, privacy: .public)")
                return .success(decodedResponse)
            case .redirection:
                logger.warning("Redirection response with status code \(statusCode) from \(path, privacy: .public)")
                return .failure(.unexpectedError(statusCode: statusCode, message: "Redirection occurred."))
            case .clientError:
                let errorMessage = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    logger.warning("Client error: \(errorResponse.combinedMessage, privacy: .public) with status code \(statusCode) from \(path, privacy: .public)")
                    return .failure(.clientError(statusCode: statusCode, message: errorResponse.combinedMessage))
                } else {
                    logger.warning("Client error: \(errorMessage, privacy: .public) with status code \(statusCode) from \(path, privacy: .public)")
                    return .failure(.clientError(statusCode: statusCode, message: errorMessage))
                }
            case .serverError:
                let errorMessage = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                var errorDetails: [String: Any]? = nil
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    errorDetails = ["error": errorResponse.error ?? "",
                                    "message": errorResponse.message ?? "",
                                    "errors": errorResponse.errors ?? [:]]
                    logger.error("Server error: \(errorResponse.combinedMessage, privacy: .public) with status code \(statusCode) from \(path, privacy: .public)")
                    return .failure(.serverError(statusCode: statusCode, message: errorResponse.combinedMessage, details: errorDetails))
                } else {
                    logger.error("Server error: \(errorMessage, privacy: .public) with status code \(statusCode) from \(path, privacy: .public)")
                    return .failure(.serverError(statusCode: statusCode, message: errorMessage, details: errorDetails))
                }
            case .cancelled:
                logger.info("Request cancelled with status code \(statusCode) from \(path, privacy: .public)")
                return .failure(.unexpectedError(statusCode: statusCode, message: "Request was cancelled."))
            case .unknown:
                logger.error("Unexpected error with status code \(statusCode) from \(path, privacy: .public)")
                return .failure(.unexpectedError(statusCode: statusCode, message: "An unexpected error occurred."))
            }
        } catch let error as NSError {
            logger.error("Unexpected error occurred: \(error.localizedDescription, privacy: .public)")
            return .failure(.unexpectedError(statusCode: nil, message: "Failed to process request (error: \(error.localizedDescription))."))
        }
    }
}
