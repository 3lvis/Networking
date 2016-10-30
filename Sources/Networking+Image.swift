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
     Retrieves an image from the cache or from the filesystem.
     - parameter path: The path where the image is located.
     - parameter cacheName: The cache name used to identify the downloaded image, by default the path is used.
     */
    public func imageFromCache(_ path: String, cacheName: String? = nil) -> NetworkingImage? {
        let object = self.objectFromCache(for: path, cacheName: cacheName, responseType: .image)

        return object as? NetworkingImage
    }

    /**
     Downloads an image using the specified path.
     - parameter path: The path where the image is located.
     - parameter cacheName: The cache name used to identify the downloaded image, by default the path is used.
     - parameter completion: A closure that gets called when the image download request is completed, it contains a image and a error.
     */
    public func downloadImage(_ path: String, cacheName: String? = nil, completion: @escaping (_ image: NetworkingImage?, _ error: NSError?) -> Void) {
        self.request(.GET, path: path, cacheName: cacheName, parameterType: nil, parameters: nil, parts: nil, responseType: .image) { response, _, error in
            TestCheck.testBlock(self.disableTestingMode) {
                completion(response as? NetworkingImage, error)
            }
        }
    }

    /**
     Cancels the image download request for the specified path. This causes the request to complete with error code -999.
     - parameter path: The path for the cancelled image download request.
     - parameter completion: A closure that gets called when the cancellation is completed.
     */
    public func cancelImageDownload(_ path: String, completion: ((Void) -> Void)? = nil) {
        let url = self.url(for: path)
        self.cancelRequest(.Data, requestType: .GET, url: url, completion: completion)
    }

    /**
     Registers a fake download image request with a image. After registering this, every download request to the path, will return the registered image.
     - parameter path: The path for the faked image download request.
     - parameter image: An image that will be returned when there's a request to the registered path.
     */
    public func fakeImageDownload(_ path: String, image: NetworkingImage?, statusCode: Int = 200) {
        self.fake(.GET, path: path, response: image, responseType: .image, statusCode: statusCode)
    }
}
