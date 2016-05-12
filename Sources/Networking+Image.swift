import Foundation

#if os(iOS) || os(tvOS) || os(watchOS)
    import UIKit
#endif

public extension Networking {
    #if os(iOS) || os(tvOS) || os(watchOS)
    public func imageFromCache(path: String, cacheName: String? = nil, completion: (image: UIImage?) -> Void) {
        self.dataFromCache(path, cacheName: cacheName) { data in
            if let data = data {
                completion(image: UIImage(data: data))
            } else {
                completion(image: nil)
            }
        }
    }

    /**
     Downloads an image using the specified path.
     - parameter path: The path where the image is located
     - parameter cacheName: The cache name used to identify the downloaded image, by default the path is used.
     - parameter completion: A closure that gets called when the image download request is completed, it contains an `UIImage` object and a `NSError`.
     */
    public func downloadImage(path: String, cacheName: String? = nil, completion: (image: UIImage?, error: NSError?) -> Void) {
        self.request(.GET, path: path, cacheName: cacheName, parameterType: .JSON, parameters: nil, responseType: .Data) { response, error in
            if let image = response as? UIImage {
                completion(image: image, error: error)
            } else if let data = response as? NSData {
                completion(image: UIImage(data: data), error: error)
            } else {
                completion(image: nil, error: error)
            }
        }
    }

    /**
     Cancels the image download request for the specified path. This causes the request to complete with error code -999
     - parameter path: The path for the cancelled image download request
     */
    public func cancelImageDownload(path: String) {
        let url = self.urlForPath(path)
        self.cancelRequest(.Data, requestType: .GET, url: url)
    }

    /**
     Registers a fake download image request with an UIImage. After registering this, every download request to the path, will return
     the registered UIImage.
     - parameter path: The path for the faked image download request.
     - parameter image: A UIImage that will be returned when there's a request to the registered path
     */
    public func fakeImageDownload(path: String, image: UIImage?, statusCode: Int = 200) {
        self.fake(.GET, path: path, response: image, statusCode: statusCode)
    }
    #endif
}

extension Networking {
    #if os(iOS) || os(tvOS) || os(watchOS)
    func dataForDestinationURL(url: NSURL) -> NSData {
        guard let data = NSFileManager.defaultManager().contentsAtPath(url.path!) else { fatalError("Couldn't get image in destination url: \(url)") }

        return data
    }
    #endif
}
