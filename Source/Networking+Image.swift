#if os(iOS) || os(tvOS) || os(watchOS)

import Foundation
import TestCheck
import UIKit
import NetworkActivityIndicator

public extension Networking {
    /**
     Downloads an image using the specified path.
     - parameter path: The path where the image is located
     - parameter completion: A closure that gets called when the image download request is completed, it contains an `UIImage` object and a `NSError`.
     */
    public func downloadImage(path: String, completion: (image: UIImage?, error: NSError?) -> ()) {
        let destinationURL = self.destinationURL(path)
        guard let filePath = self.destinationURL(path).path else { fatalError("File path not valid") }

        if let getStubs = self.stubs[.GET], image = getStubs[path] as? UIImage {
            completion(image: image, error: nil)
        } else if let image = self.imageCache.objectForKey(destinationURL.absoluteString) as? UIImage {
            completion(image: image, error: nil)
        } else if NSFileManager().fileExistsAtPath(filePath) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), {
                if let data = NSData(contentsOfURL: destinationURL), image = UIImage(data: data) {
                    dispatch_async(dispatch_get_main_queue(), {
                        completion(image: image, error: nil)
                    })
                    self.imageCache.setObject(image, forKey: filePath)
                }
            })
        } else {
            let request = NSMutableURLRequest(URL: self.urlForPath(path))
            request.HTTPMethod = RequestType.GET.rawValue
            request.addValue("application/json", forHTTPHeaderField: "Accept")

            if let token = token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let semaphore = dispatch_semaphore_create(0)
            var returnedData: NSData?
            var returnedImage: UIImage?
            var returnedError: NSError?
            var returnedResponse: NSURLResponse?

            NetworkActivityIndicator.sharedIndicator.visible = true

            self.session.downloadTaskWithRequest(request, completionHandler: { url, response, error in
                returnedResponse = response
                returnedError = error

                if let url = url, data = NSData(contentsOfURL: url), image = UIImage(data: data) {
                    returnedData = data
                    returnedImage = image

                    data.writeToURL(destinationURL, atomically: true)
                    self.imageCache.setObject(image, forKey: filePath)
                }

                if TestCheck.isTesting && self.disableTestingMode == false {
                    dispatch_semaphore_signal(semaphore)
                } else {
                    dispatch_async(dispatch_get_main_queue(), {
                        NetworkActivityIndicator.sharedIndicator.visible = false

                        self.logError(nil, data: returnedData, request: request, response: response, error: error)
                        completion(image: returnedImage, error: error)
                    })
                }
            }).resume()

            if TestCheck.isTesting && self.disableTestingMode == false {
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

                self.logError(nil, data: returnedData, request: request, response: returnedResponse, error: returnedError)
                completion(image: returnedImage, error: returnedError)
            }
        }
    }

    /**
     Cancels the image download request for the specified path. This causes the request to complete with error code -999
     - parameter path: The path for the cancelled image download request
     */
    public func cancelImageDownload(path: String) {
        self.cancelRequest(.Download, requestType: .GET, path: path)
    }

    /**
     Stubs a download image request with an UIImage. After registering this, every download request to the path, will return
     the registered UIImage.
     - parameter path: The path for the stubbed image download.
     - parameter image: A UIImage that will be returned when there's a request to the registered path
     */
    public func stubImageDownload(path: String, image: UIImage) {
        self.stub(.GET, path: path, response: image)
    }
}

#endif
