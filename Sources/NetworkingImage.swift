#if os(OSX)
    import AppKit.NSImage
    public typealias NetworkingImage = NSImage
#else
    import UIKit.UIImage
    public typealias NetworkingImage = UIImage
#endif


/**
 Helper methods to handle UIImage and NSImage related tasks.
 */
extension NetworkingImage {
    static func find(named name: String, inBundle bundle: Bundle) -> NetworkingImage {
        #if os(OSX)
            return bundle.image(forResource: name)!
        #elseif os(watchOS)
            return UIImage(named: name)!
        #else
            return UIImage(named: name, in: bundle, compatibleWith: nil)!
        #endif
    }

    #if os(OSX)
    func data(type: NSBitmapImageFileType) -> Data? {
        let imageData = self.tiffRepresentation!
        let bitmapImageRep = NSBitmapImageRep(data: imageData)!
        let data = bitmapImageRep.representation(using: type, properties: [String : AnyObject]())
        return data
    }
    #endif

    func pngData() -> Data? {
        #if os(OSX)
            return self.data(type: .PNG)
        #else
            return UIImagePNGRepresentation(self)
        #endif
    }

    func jpgData() -> Data? {
        #if os(OSX)
            return self.data(type: .JPEG)
        #else
            return UIImageJPEGRepresentation(self, 1)
        #endif
    }
}
