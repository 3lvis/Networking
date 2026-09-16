#if os(macOS)
    import AppKit.NSImage
    public typealias Image = NSImage
#else
    import UIKit.UIImage
    public typealias Image = UIImage
#endif

extension Image {
    static func find(named name: String, inBundle bundle: Bundle) -> Image {
        #if os(macOS)
            let found = bundle.image(forResource: name)
        #elseif os(watchOS)
            let found = UIImage(named: name)
        #else
            let found = UIImage(
                named: name,
                in: bundle,
                compatibleWith: nil
            )
        #endif
        guard let found else {
            // The asset ships inside the bundle, so its absence is a packaging fault, not a caller's.
            fatalError("\(bundle.bundleURL.lastPathComponent) carries no image named \(name)")
        }
        return found
    }

    #if os(macOS)
        func data(_ type: NSBitmapImageRep.FileType) -> Data? {
            guard let imageData = tiffRepresentation, let bitmapImageRep = NSBitmapImageRep(data: imageData) else {
                return nil
            }
            return bitmapImageRep.representation(using: type, properties: [NSBitmapImageRep.PropertyKey: Any]())
        }
    #endif

    #if os(macOS)
        func pngData() -> Data? {
            return data(.png)
        }
    #endif

    func jpgData() -> Data? {
        #if os(macOS)
            return data(.jpeg)
        #else
            return self.jpegData(compressionQuality: 1)
        #endif
    }
}
