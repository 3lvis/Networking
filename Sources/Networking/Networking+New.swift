import Foundation

extension Networking {
    func handle<T: Decodable>(_ requestType: RequestType, path: String, parameters: Any?) async -> Result<T, NetworkingError> {
        do {
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
                    return .success(decodedResponse)
                case .failure(let response):
                    return .failure(.unexpectedError(statusCode: nil, message: "Failed to process fake raquest (error: \(response.error.localizedDescription))."))
                }
            }

            let parameterType: Networking.ParameterType? = parameters != nil ? .json : nil
            var request = URLRequest(url: try composedURL(with: path), requestType: requestType, path: path, parameterType: parameterType, responseType: .json, boundary: boundary, authorizationHeaderValue: authorizationHeaderValue, token: token, authorizationHeaderKey: authorizationHeaderKey, headerFields: headerFields)

            if let parameters = parameters {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
            }

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            let statusCode = httpResponse.statusCode
            if (200...299).contains(statusCode) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let decodedResponse = try decoder.decode(T.self, from: data)
                return .success(decodedResponse)
            } else {
                let errorMessage = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                var message = errorMessage
                var errorDetails: [String: Any]? = nil

                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    message = errorResponse.combinedMessage
                    errorDetails = ["error": errorResponse.error ?? "",
                                    "message": errorResponse.message ?? "",
                                    "errors": errorResponse.errors ?? [:]]
                }

                if (400...499).contains(statusCode) {
                    return .failure(.clientError(statusCode: statusCode, message: message))
                } else if (500...599).contains(statusCode) {
                    return .failure(.serverError(statusCode: statusCode, message: message, details: errorDetails))
                } else {
                    return .failure(.unexpectedError(statusCode: statusCode, message: "An unexpected error occurred."))
                }
            }

        } catch let error as NSError {
            return .failure(.unexpectedError(statusCode: nil, message: "Failed to process fake raquest (error: \(error.localizedDescription))."))
        }
    }
}
