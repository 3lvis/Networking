import Foundation

public extension Networking {
    /**
     Retrieves an image from the cache or from the filesystem.
     - parameter path: The path where the image is located.
     - parameter cacheName: The cache name used to identify the downloaded image, by default the path is used.
     - parameter completion: A closure that returns the image from the cache, if no image is found it will return nil, it contains a image and a error.
     */
    public func imageFromCache(path: String, cacheName: String? = nil, completion: (image: NetworkingImage?) -> Void) {
        self.objectFromCache(path, cacheName: cacheName, responseType: .Image) { object in
            TestCheck.testBlock(disabled: self.disableTestingMode) {
                completion(image: object as? NetworkingImage)
            }
        }
    }

    /**
     Downloads an image using the specified path.
     - parameter path: The path where the image is located.
     - parameter cacheName: The cache name used to identify the downloaded image, by default the path is used.
     - parameter completion: A closure that gets called when the image download request is completed, it contains a image and a error.
     */
    public func downloadImage(path: String, cacheName: String? = nil, completion: (image: NetworkingImage?, error: NSError?) -> Void) {
        self.request(.GET, path: path, cacheName: cacheName, parameterType: nil, parameters: nil, responseType: .Image) { response, error in
            TestCheck.testBlock(disabled: self.disableTestingMode) {
                completion(image: response as? NetworkingImage, error: error)
            }
        }
    }

    /**
     Cancels the image download request for the specified path. This causes the request to complete with error code -999.
     - parameter path: The path for the cancelled image download request.
     */
    public func cancelImageDownload(path: String) {
        let url = self.urlForPath(path)
        self.cancelRequest(.Data, requestType: .GET, url: url)
    }

    /**
     Registers a fake download image request with a image. After registering this, every download request to the path, will return the registered image.
     - parameter path: The path for the faked image download request.
     - parameter image: An image that will be returned when there's a request to the registered path.
     */
    public func fakeImageDownload(path: String, image: NetworkingImage?, statusCode: Int = 200) {
        self.fake(.GET, path: path, response: image, statusCode: statusCode)
    }
}