import Foundation

extension Networking {

    // MARK: GET

    public func get<T: Decodable>(_ path: String, query: [URLQueryItem]? = nil, cachingLevel: CachingLevel = .none)
        async -> Result<T, NetworkingError>
    {
        return await handle(.get, path: path, query: query ?? [], cachingLevel: cachingLevel)
    }

    public func get<Q: Encodable, T: Decodable>(_ path: String, query: Q, cachingLevel: CachingLevel = .none) async
        -> Result<T, NetworkingError>
    {
        return await queryEncodeAndHandle(.get, path: path, query: query, cachingLevel: cachingLevel)
    }

    // MARK: POST

    public func post<T: Decodable>(_ path: String) async -> Result<T, NetworkingError> {
        return await handle(.post, path: path)
    }

    public func post(_ path: String) async -> Result<Void, NetworkingError> {
        let result: Result<Data, NetworkingError> = await handle(.post, path: path)
        return result.map { _ in () }
    }

    /// JSON body, ISO-8601 dates.
    public func post<B: Encodable, T: Decodable>(_ path: String, body: B) async -> Result<T, NetworkingError> {
        return await encodeAndHandle(.post, path: path, body: body)
    }

    public func post<B: Encodable>(_ path: String, body: B) async -> Result<Void, NetworkingError> {
        let result: Result<Data, NetworkingError> = await encodeAndHandle(.post, path: path, body: body)
        return result.map { _ in () }
    }

    /// `application/x-www-form-urlencoded` body, built from a flat `Encodable`.
    public func post<F: Encodable, T: Decodable>(_ path: String, form: F) async -> Result<T, NetworkingError> {
        return await formEncodeAndHandle(.post, path: path, form: form)
    }

    public func post<F: Encodable>(_ path: String, form: F) async -> Result<Void, NetworkingError> {
        let result: Result<Data, NetworkingError> = await formEncodeAndHandle(.post, path: path, form: form)
        return result.map { _ in () }
    }

    public func post<T: Decodable>(_ path: String, parts: [FormDataPart], fields: [String: String] = [:]) async
        -> Result<T, NetworkingError>
    {
        return await handle(.post, path: path, body: .multipart(fields: fields, parts: parts))
    }

    public func post(_ path: String, parts: [FormDataPart], fields: [String: String] = [:]) async -> Result<
        Void, NetworkingError
    > {
        let result: Result<Data, NetworkingError> = await handle(
            .post, path: path, body: .multipart(fields: fields, parts: parts))
        return result.map { _ in () }
    }

    public func post<T: Decodable>(_ path: String, data: Data, contentType: String) async -> Result<T, NetworkingError>
    {
        return await handle(.post, path: path, body: .raw(data, contentType: contentType))
    }

    public func post(_ path: String, data: Data, contentType: String) async -> Result<Void, NetworkingError> {
        let result: Result<Data, NetworkingError> = await handle(
            .post, path: path, body: .raw(data, contentType: contentType))
        return result.map { _ in () }
    }

    // MARK: PUT

    public func put<T: Decodable>(_ path: String) async -> Result<T, NetworkingError> {
        return await handle(.put, path: path)
    }

    public func put(_ path: String) async -> Result<Void, NetworkingError> {
        let result: Result<Data, NetworkingError> = await handle(.put, path: path)
        return result.map { _ in () }
    }

    public func put<B: Encodable, T: Decodable>(_ path: String, body: B) async -> Result<T, NetworkingError> {
        return await encodeAndHandle(.put, path: path, body: body)
    }

    public func put<B: Encodable>(_ path: String, body: B) async -> Result<Void, NetworkingError> {
        let result: Result<Data, NetworkingError> = await encodeAndHandle(.put, path: path, body: body)
        return result.map { _ in () }
    }

    public func put<F: Encodable, T: Decodable>(_ path: String, form: F) async -> Result<T, NetworkingError> {
        return await formEncodeAndHandle(.put, path: path, form: form)
    }

    public func put<F: Encodable>(_ path: String, form: F) async -> Result<Void, NetworkingError> {
        let result: Result<Data, NetworkingError> = await formEncodeAndHandle(.put, path: path, form: form)
        return result.map { _ in () }
    }

    public func put<T: Decodable>(_ path: String, parts: [FormDataPart], fields: [String: String] = [:]) async
        -> Result<T, NetworkingError>
    {
        return await handle(.put, path: path, body: .multipart(fields: fields, parts: parts))
    }

    public func put(_ path: String, parts: [FormDataPart], fields: [String: String] = [:]) async -> Result<
        Void, NetworkingError
    > {
        let result: Result<Data, NetworkingError> = await handle(
            .put, path: path, body: .multipart(fields: fields, parts: parts))
        return result.map { _ in () }
    }

    public func put<T: Decodable>(_ path: String, data: Data, contentType: String) async -> Result<T, NetworkingError> {
        return await handle(.put, path: path, body: .raw(data, contentType: contentType))
    }

    public func put(_ path: String, data: Data, contentType: String) async -> Result<Void, NetworkingError> {
        let result: Result<Data, NetworkingError> = await handle(
            .put, path: path, body: .raw(data, contentType: contentType))
        return result.map { _ in () }
    }

    // MARK: PATCH

    public func patch<T: Decodable>(_ path: String) async -> Result<T, NetworkingError> {
        return await handle(.patch, path: path)
    }

    public func patch(_ path: String) async -> Result<Void, NetworkingError> {
        let result: Result<Data, NetworkingError> = await handle(.patch, path: path)
        return result.map { _ in () }
    }

    public func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async -> Result<T, NetworkingError> {
        return await encodeAndHandle(.patch, path: path, body: body)
    }

    public func patch<B: Encodable>(_ path: String, body: B) async -> Result<Void, NetworkingError> {
        let result: Result<Data, NetworkingError> = await encodeAndHandle(.patch, path: path, body: body)
        return result.map { _ in () }
    }

    public func patch<F: Encodable, T: Decodable>(_ path: String, form: F) async -> Result<T, NetworkingError> {
        return await formEncodeAndHandle(.patch, path: path, form: form)
    }

    public func patch<F: Encodable>(_ path: String, form: F) async -> Result<Void, NetworkingError> {
        let result: Result<Data, NetworkingError> = await formEncodeAndHandle(.patch, path: path, form: form)
        return result.map { _ in () }
    }

    public func patch<T: Decodable>(_ path: String, parts: [FormDataPart], fields: [String: String] = [:]) async
        -> Result<T, NetworkingError>
    {
        return await handle(.patch, path: path, body: .multipart(fields: fields, parts: parts))
    }

    public func patch(_ path: String, parts: [FormDataPart], fields: [String: String] = [:]) async -> Result<
        Void, NetworkingError
    > {
        let result: Result<Data, NetworkingError> = await handle(
            .patch, path: path, body: .multipart(fields: fields, parts: parts))
        return result.map { _ in () }
    }

    public func patch<T: Decodable>(_ path: String, data: Data, contentType: String) async -> Result<T, NetworkingError>
    {
        return await handle(.patch, path: path, body: .raw(data, contentType: contentType))
    }

    public func patch(_ path: String, data: Data, contentType: String) async -> Result<Void, NetworkingError> {
        let result: Result<Data, NetworkingError> = await handle(
            .patch, path: path, body: .raw(data, contentType: contentType))
        return result.map { _ in () }
    }

    // MARK: DELETE

    public func delete<T: Decodable>(_ path: String, query: [URLQueryItem]? = nil) async -> Result<T, NetworkingError> {
        return await handle(.delete, path: path, query: query ?? [])
    }

    public func delete(_ path: String, query: [URLQueryItem]? = nil) async -> Result<Void, NetworkingError> {
        let result: Result<Data, NetworkingError> = await handle(.delete, path: path, query: query ?? [])
        return result.map { _ in () }
    }

    public func delete<Q: Encodable, T: Decodable>(_ path: String, query: Q) async -> Result<T, NetworkingError> {
        return await queryEncodeAndHandle(.delete, path: path, query: query, cachingLevel: .none)
    }

    public func delete<Q: Encodable>(_ path: String, query: Q) async -> Result<Void, NetworkingError> {
        let result: Result<Data, NetworkingError> = await queryEncodeAndHandle(
            .delete, path: path, query: query, cachingLevel: .none)
        return result.map { _ in () }
    }
}

extension Networking {
    // ISO-8601 dates so an encoded `Date` round-trips with the decoder's `.iso8601` strategy.
    static let requestBodyEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func encodeAndHandle<B: Encodable, T: Decodable>(_ requestType: RequestType, path: String, body: B) async -> Result<
        T, NetworkingError
    > {
        let data: Data
        do {
            data = try Self.requestBodyEncoder.encode(body)
        } catch {
            return emitPreflightFailure(
                requestType, path: path,
                error: .invalidRequest(.bodyEncodingFailed(message: error.localizedDescription)))
        }
        return await handle(requestType, path: path, body: .json(data))
    }

    // A fake whose response can't encode is a test setup bug — fail loudly here rather than silently
    // registering an empty body that breaks later, somewhere less obvious.
    fileprivate func fakePayload(_ response: some Encodable) -> FakeRequest.Payload {
        do {
            return .data(try Self.requestBodyEncoder.encode(response))
        } catch {
            fatalError("Networking: fake response of type \(type(of: response)) failed to encode: \(error)")
        }
    }
}

extension Networking {
    func formEncodeAndHandle<T: Decodable>(_ requestType: RequestType, path: String, form: some Encodable) async
        -> Result<T, NetworkingError>
    {
        let fields: [String: String]
        do {
            fields = try formFields(from: form)
        } catch {
            return emitPreflightFailure(
                requestType, path: path,
                error: .invalidRequest(.parameterEncodingFailed(message: error.localizedDescription)))
        }
        return await handle(requestType, path: path, body: .formURLEncoded(fields))
    }

    func queryEncodeAndHandle<T: Decodable>(
        _ requestType: RequestType, path: String, query: some Encodable, cachingLevel: CachingLevel
    ) async -> Result<T, NetworkingError> {
        let items: [URLQueryItem]
        do {
            items = try formFields(from: query).map { URLQueryItem(name: $0.key, value: $0.value) }
        } catch {
            return emitPreflightFailure(
                requestType, path: path,
                error: .invalidRequest(.parameterEncodingFailed(message: error.localizedDescription)))
        }
        return await handle(requestType, path: path, query: items, cachingLevel: cachingLevel)
    }
}

// MARK: - Faking requests

extension Networking {
    public func fakeGET(
        _ path: String, response: some Encodable, headerFields: [String: String]? = nil, statusCode: Int = 200,
        delay: Double = 0
    ) {
        registerFake(
            requestType: .get, path: path, headerFields: headerFields, payload: fakePayload(response),
            responseType: .json, statusCode: statusCode, delay: delay)
    }

    public func fakeGET(_ path: String, headerFields: [String: String]? = nil, statusCode: Int = 200, delay: Double = 0)
    {
        registerFake(
            requestType: .get, path: path, headerFields: headerFields, payload: .none, responseType: .json,
            statusCode: statusCode, delay: delay)
    }

    public func fakeGET(
        _ path: String, fileName: String, bundle: Bundle = Bundle.main, statusCode: Int = 200, delay: Double = 0
    ) {
        registerFake(
            requestType: .get, path: path, fileName: fileName, bundle: bundle, statusCode: statusCode, delay: delay)
    }

    public func fakePOST(
        _ path: String, response: some Encodable, headerFields: [String: String]? = nil, statusCode: Int = 200,
        delay: Double = 0
    ) {
        registerFake(
            requestType: .post, path: path, headerFields: headerFields, payload: fakePayload(response),
            responseType: .json, statusCode: statusCode, delay: delay)
    }

    public func fakePOST(
        _ path: String, headerFields: [String: String]? = nil, statusCode: Int = 200, delay: Double = 0
    ) {
        registerFake(
            requestType: .post, path: path, headerFields: headerFields, payload: .none, responseType: .json,
            statusCode: statusCode, delay: delay)
    }

    public func fakePOST(
        _ path: String, fileName: String, bundle: Bundle = Bundle.main, statusCode: Int = 200, delay: Double = 0
    ) {
        registerFake(
            requestType: .post, path: path, fileName: fileName, bundle: bundle, statusCode: statusCode, delay: delay)
    }

    public func fakePUT(
        _ path: String, response: some Encodable, headerFields: [String: String]? = nil, statusCode: Int = 200,
        delay: Double = 0
    ) {
        registerFake(
            requestType: .put, path: path, headerFields: headerFields, payload: fakePayload(response),
            responseType: .json, statusCode: statusCode, delay: delay)
    }

    public func fakePUT(_ path: String, headerFields: [String: String]? = nil, statusCode: Int = 200, delay: Double = 0)
    {
        registerFake(
            requestType: .put, path: path, headerFields: headerFields, payload: .none, responseType: .json,
            statusCode: statusCode, delay: delay)
    }

    public func fakePUT(
        _ path: String, fileName: String, bundle: Bundle = Bundle.main, statusCode: Int = 200, delay: Double = 0
    ) {
        registerFake(
            requestType: .put, path: path, fileName: fileName, bundle: bundle, statusCode: statusCode, delay: delay)
    }

    public func fakePATCH(
        _ path: String, response: some Encodable, headerFields: [String: String]? = nil, statusCode: Int = 200,
        delay: Double = 0
    ) {
        registerFake(
            requestType: .patch, path: path, headerFields: headerFields, payload: fakePayload(response),
            responseType: .json, statusCode: statusCode, delay: delay)
    }

    public func fakePATCH(
        _ path: String, headerFields: [String: String]? = nil, statusCode: Int = 200, delay: Double = 0
    ) {
        registerFake(
            requestType: .patch, path: path, headerFields: headerFields, payload: .none, responseType: .json,
            statusCode: statusCode, delay: delay)
    }

    public func fakePATCH(
        _ path: String, fileName: String, bundle: Bundle = Bundle.main, statusCode: Int = 200, delay: Double = 0
    ) {
        registerFake(
            requestType: .patch, path: path, fileName: fileName, bundle: bundle, statusCode: statusCode, delay: delay)
    }

    public func fakeDELETE(
        _ path: String, response: some Encodable, headerFields: [String: String]? = nil, statusCode: Int = 200,
        delay: Double = 0
    ) {
        registerFake(
            requestType: .delete, path: path, headerFields: headerFields, payload: fakePayload(response),
            responseType: .json, statusCode: statusCode, delay: delay)
    }

    public func fakeDELETE(
        _ path: String, headerFields: [String: String]? = nil, statusCode: Int = 200, delay: Double = 0
    ) {
        registerFake(
            requestType: .delete, path: path, headerFields: headerFields, payload: .none, responseType: .json,
            statusCode: statusCode, delay: delay)
    }

    public func fakeDELETE(
        _ path: String, fileName: String, bundle: Bundle = Bundle.main, statusCode: Int = 200, delay: Double = 0
    ) {
        registerFake(
            requestType: .delete, path: path, fileName: fileName, bundle: bundle, statusCode: statusCode, delay: delay)
    }
}

// MARK: - Downloads

extension Networking {

    public nonisolated func imageFromCache(_ path: String, cacheName: String? = nil) throws -> Image? {
        let object = try objectFromCache(
            for: path, cacheName: cacheName, cachingLevel: .memoryAndFile, responseType: .image)

        return object as? Image
    }

    public func downloadImage<T: ImageDownloadable>(
        _ path: String, cacheName: String? = nil, cachingLevel: CachingLevel = .memoryAndFile
    ) async -> Result<T, NetworkingError> {
        return await handleImageRequest(
            .get, path: path, cacheName: cacheName, cachingLevel: cachingLevel, responseType: .image)
    }

    /// Completes the in-flight download for `path` with `URLError.cancelled`.
    public func cancelImageDownload(_ path: String) async throws {
        let url = try composedURL(with: path)
        await cancelRequest(.data, requestType: .get, url: url)
    }

    public func fakeImageDownload(
        _ path: String, image: Image, headerFields: [String: String]? = nil, statusCode: Int = 200, delay: Double = 0
    ) {
        registerFake(
            requestType: .get, path: path, headerFields: headerFields, payload: .image(image), responseType: .image,
            statusCode: statusCode, delay: delay)
    }

    public func downloadData<T: DataDownloadable>(
        _ path: String, cacheName: String? = nil, cachingLevel: CachingLevel = .memoryAndFile
    ) async -> Result<T, NetworkingError> {
        return await handleDataRequest(
            .get, path: path, cacheName: cacheName, cachingLevel: cachingLevel, responseType: .data)
    }

    public nonisolated func dataFromCache(_ path: String, cacheName: String? = nil) throws -> Data? {
        let object = try objectFromCache(
            for: path, cacheName: cacheName, cachingLevel: .memoryAndFile, responseType: .data)

        return object as? Data
    }
}
