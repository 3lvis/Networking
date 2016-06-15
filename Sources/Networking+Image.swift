import Foundation

#if os(iOS) || os(tvOS) || os(watchOS)
    import UIKit
#endif

public extension Networking {
    #if os(iOS) || os(tvOS) || os(watchOS)
    /**
     Retrieves an image from the cache or from the filesystem
     - parameter path: The path where the image is located
     - parameter cacheName: The cache name used to identify the downloaded image, by default the path is used.
     - parameter completion: A closure that returns the image from the cache, if no image is found it will 
     return nil, it contains an `UIImage` object and a `NSError`.
     */
    public func imageFromCache(_ path: String, cacheName: String? = nil, completion: (image: UIImage?) -> Void) {
        let destinationURL = self.destinationURL(path, cacheName: cacheName)
        let semaphore = DispatchSemaphore(value: 0)
        var returnedImage: UIImage?

        if let image = self.cache.object(forKey: destinationURL.absoluteString!) as? UIImage {
            completion(image: image)
        } else if FileManager.default().fileExistsAtURL(destinationURL) {
            DispatchQueue.global(attributes: DispatchQueue.GlobalAttributes.qosUtility).async {
                let image = self.imageForDestinationURL(destinationURL)
                returnedImage = image
                self.cache.setObject(image, forKey: destinationURL.absoluteString!)
                if TestCheck.isTesting && self.disableTestingMode == false {
                    semaphore.signal()
                } else {
                    DispatchQueue.main.async {
                        completion(image: image)
                    }
                }
            }

            if TestCheck.isTesting && self.disableTestingMode == false {
                semaphore.wait(timeout: DispatchTime.distantFuture)
                completion(image: returnedImage)
            }
        } else {
            completion(image: nil)
        }
    }

    /**
     Downloads an image using the specified path.
     - parameter path: The path where the image is located
     - parameter cacheName: The cache name used to identify the downloaded image, by default the path is used.
     - parameter completion: A closure that gets called when the image download request is completed, it contains an `UIImage` object and a `NSError`.
     */
    public func downloadImage(_ path: String, cacheName: String? = nil, completion: (image: UIImage?, error: NSError?) -> Void) {
        if let getFakeRequests = self.fakeRequests[.GET], fakeRequest = getFakeRequests[path] {
            if fakeRequest.statusCode.statusCodeType() == .successful, let image = fakeRequest.response as? UIImage {
                completion(image: image, error: nil)
            } else {
                let error = NSError(domain: Networking.ErrorDomain, code: fakeRequest.statusCode, userInfo: [NSLocalizedDescriptionKey : HTTPURLResponse.localizedString(forStatusCode: fakeRequest.statusCode)])
                completion(image: nil, error: error)
            }
        } else {
            self.imageFromCache(path, cacheName: cacheName) { image in
                if let image = image {
                    completion(image: image, error: nil)
                } else {
                    let destinationURL = self.destinationURL(path, cacheName: cacheName)
                    let requestURL = self.urlForPath(path)
                    let request = NSMutableURLRequest(url: requestURL)
                    request.httpMethod = RequestType.GET.rawValue
                    request.addValue("application/json", forHTTPHeaderField: "Accept")

                    if let token = self.token {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }

                    let semaphore = DispatchSemaphore(value: 0)
                    var returnedData: Data?
                    var returnedImage: UIImage?
                    var returnedError: NSError?
                    var returnedResponse: URLResponse?

                    NetworkActivityIndicator.sharedIndicator.visible = true

                    self.session.downloadTask(with: request as URLRequest) { url, response, error in
                        returnedResponse = response
                        returnedError = error

                        if returnedError == nil, let url = url, data = try? Data(contentsOf: url), image = UIImage(data: data) {
                            returnedData = data
                            returnedImage = image

                            try! data.write(to: destinationURL, options: [.dataWritingAtomic])
                            self.cache.setObject(image, forKey: destinationURL.absoluteString!)
                        } else if let url = url {
                            if let response = response as? HTTPURLResponse {
                                returnedError = NSError(domain: Networking.ErrorDomain, code: response.statusCode, userInfo: [NSLocalizedDescriptionKey : HTTPURLResponse.localizedString(forStatusCode: response.statusCode)])
                            } else {
                                returnedError = NSError(domain: Networking.ErrorDomain, code: 500, userInfo: [NSLocalizedDescriptionKey : "Failed to load url: \(url.absoluteString)"])
                            }
                        }

                        if TestCheck.isTesting && self.disableTestingMode == false {
                            semaphore.signal()
                        } else {
                            DispatchQueue.main.async {
                                NetworkActivityIndicator.sharedIndicator.visible = false

                                self.logError(.json, parameters: nil, data: returnedData, request: request as URLRequest, response: response, error: returnedError)
                                completion(image: returnedImage, error: returnedError)
                            }
                        }
                        }.resume()

                    if TestCheck.isTesting && self.disableTestingMode == false {
                        semaphore.wait(timeout: DispatchTime.distantFuture)
                        self.logError(.json, parameters: nil, data: returnedData, request: request as URLRequest, response: returnedResponse, error: returnedError)
                        completion(image: returnedImage, error: returnedError)
                    }
                }
            }
        }
    }

    /**
     Cancels the image download request for the specified path. This causes the request to complete with error code -999
     - parameter path: The path for the cancelled image download request
     */
    public func cancelImageDownload(_ path: String) {
        let url = self.urlForPath(path)
        self.cancelRequest(.Download, requestType: .GET, url: url)
    }

    /**
     Registers a fake download image request with an UIImage. After registering this, every download request to the path, will return
     the registered UIImage.
     - parameter path: The path for the faked image download request.
     - parameter image: A UIImage that will be returned when there's a request to the registered path
     */
    public func fakeImageDownload(_ path: String, image: UIImage?, statusCode: Int = 200) {
        self.fake(.GET, path: path, response: image, statusCode: statusCode)
    }
    #endif
}

extension Networking {
    #if os(iOS) || os(tvOS) || os(watchOS)
    func imageForDestinationURL(_ url: URL) -> UIImage {
        guard let data = FileManager.default().contents(atPath: url.path!) else { fatalError("Couldn't get image in destination url: \(url)") }
        guard let image = UIImage(data: data) else { fatalError("Couldn't get convert image using data: \(data)") }
        
        return image
    }
    #endif
}
