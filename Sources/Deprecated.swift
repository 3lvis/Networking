import Foundation

public extension Networking {

    /**
     Retrieves an image from the cache or from the filesystem.
     - parameter path: The path where the image is located.
     - parameter cacheName: The cache name used to identify the downloaded image, by default the path is used.
     - parameter completion: A closure that returns the image from the cache, if no image is found it will return nil, it contains a image and a error.
     */
    @available(*, deprecated: 2.0.1, message: "Use `imageFromCache(path: String, cacheName: String?)` instead. The asynchronous version will be removed since it's synchronous now.")
    public func imageFromCache(_ path: String, cacheName: String? = nil, completion: @escaping (_ image: NetworkingImage?) -> Void) {
        let object = self.imageFromCache(path, cacheName: cacheName)

        TestCheck.testBlock(self.disableTestingMode) {
            completion(object)
        }
    }

    /**
     Authenticates using Basic Authentication, it converts username:password to Base64 then sets the Authorization header to "Basic \(Base64(username:password))".
     - parameter username: The username to be used.
     - parameter password: The password to be used.
     */
    @available(*, deprecated: 2.2.0, message: "Use `setAuthorizationHeader(username:password:)` instead.")
    public func authenticate(username: String, password: String) {
        self.setAuthorizationHeader(username: username, password: password)
    }

    /**
     Authenticates using a Bearer token, sets the Authorization header to "Bearer \(token)".
     - parameter token: The token to be used.
     */
    @available(*, deprecated: 2.2.0, message: "Use `setAuthorizationHeader(token:)` instead")
    public func authenticate(token: String) {
        self.setAuthorizationHeader(token: token)
    }

    /**
     Authenticates using a custom HTTP Authorization header.
     - parameter authorizationHeaderKey: Sets this value as the key for the HTTP `Authorization` header
     - parameter authorizationHeaderValue: Sets this value to the HTTP `Authorization` header or to the `headerKey` if you provided that.
     */
    @available(*, deprecated: 2.2.0, message: "Use `setAuthorizationHeader(headerKey:headerValue:)` instead.")
    public func authenticate(headerKey: String = "Authorization", headerValue: String) {
        self.setAuthorizationHeader(headerKey: headerKey, headerValue: headerValue)
    }

    /**
     Retrieves data from the cache or from the filesystem.
     - parameter path: The path where the image is located.
     - parameter cacheName: The cache name used to identify the downloaded data, by default the path is used.
     - parameter completion: A closure that returns the data from the cache, if no data is found it will return nil.
     */
    @available(*, deprecated: 2.0.1, message: "Use `dataFromCache(path: String, cacheName: String?)` instead. The asynchronous version will be removed since it's synchronous now.")
    public func dataFromCache(for path: String, cacheName: String? = nil, completion: @escaping (_ data: Data?) -> Void) {
        let object = self.dataFromCache(for: path, cacheName: cacheName)

        TestCheck.testBlock(self.disableTestingMode) {
            completion(object)
        }
    }
}
