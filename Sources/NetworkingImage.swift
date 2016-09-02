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
    static func find(named name: String, inBundle bundle: NSBundle) -> NetworkingImage {
        #if os(OSX)
            return bundle.imageForResource(name)!
        #elseif os(watchOS)
            return UIImage(named: name)!
        #else
            return UIImage(named: name, inBundle: bundle, compatibleWithTraitCollection: nil)!
        #endif
    }

    #if os(OSX)
    func data(type type: NSBitmapImageFileType) -> NSData? {
        let imageData = self.TIFFRepresentation!
        let bitmapImageRep = NSBitmapImageRep(data: imageData)!
        let data = bitmapImageRep.representationUsingType(type, properties: [String : AnyObject]())
        return data
    }
    #endif

    func pngData() -> NSData? {
        #if os(OSX)
            #if swift(>=2.3)
                return self.data(type: .PNG)
            #else
                return self.data(type: .NSPNGFileType)
            #endif
        #else
            return UIImagePNGRepresentation(self)
        #endif
    }

    func jpgData() -> NSData? {
        #if os(OSX)
            #if swift(>=2.3)
                return self.data(type: .JPEG)
            #else
                return self.data(type: .NSJPEGFileType)
            #endif
        #else
            return UIImageJPEGRepresentation(self, 1)
        #endif
    }
}
