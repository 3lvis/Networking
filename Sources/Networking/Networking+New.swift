import Foundation

extension Networking {
    func handle<T: Decodable>(_ requestType: RequestType, path: String, parameters: Any?) async -> Result<T, NetworkingError> {
        do {
            logger.info("Starting \(requestType.rawValue) request to \(path, privacy: .public)")

            if let fakeRequest = try FakeRequest.find(ofType: requestType, forPath: path, in: fakeRequests) {
                return try await handleFakeRequest(fakeRequest, path: path, requestType: requestType)
            }

            let request = try createRequest(path: path, requestType: requestType, parameters: parameters)
            let (responseData, response) = try await session.data(for: request)
            return try handleResponse(responseData: responseData, response: response, path: path)

        } catch {
            return handleRequestError(error: error)
        }
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
        guard var urlComponents = URLComponents(string: try composedURL(with: path).absoluteString) else {
            throw URLError(.badURL)
        }

        if requestType == .get, let queryParameters = parameters as? [String: Any] {
            urlComponents.queryItems = queryParameters.map { key, value in
                URLQueryItem(name: key, value: "\(value)")
            }
        }

        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }

        let parameterType: Networking.ParameterType? = (requestType == .get || parameters == nil) ? nil : .json
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

        if requestType != .get, let parameters = parameters {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        }

        return request
    }

    private func handleResponse<T: Decodable>(responseData: Data, response: URLResponse, path: String) throws -> Result<T, NetworkingError> {
        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.invalidResponse)
        }

        let statusCode = httpResponse.statusCode

        if (statusCode == 401 || statusCode == 403),
           let callback = unauthorizedRequestCallback {
            callback()
        }

        switch statusCode.statusCodeType {
        case .informational, .successful:
            return try handleSuccessfulResponse(responseData: responseData, path: path, httpResponse: httpResponse)
        case .redirection:
            return .failure(.unexpectedError(statusCode: statusCode, message: "Redirection occurred."))
        case .clientError:
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
            let networkingJSON = NetworkingResponse(headers: headers, body: body)
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
        if let decodingError = error as? DecodingError {
            logger.error("Unexpected error occurred: \(decodingError.detailedMessage, privacy: .public)")
        } else {
            logger.error("Unexpected error occurred: \(error.localizedDescription, privacy: .public)")
        }
        return .failure(.unexpectedError(statusCode: nil, message: "Failed to process request (error: \(error.localizedDescription))."))
    }
}
