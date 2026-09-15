import Foundation

#if os(macOS)
    import AppKit.NSImage
#else
    import UIKit.UIImage
#endif

/// The payload types a `downloadImage` call can produce: the bare `Image`, or an `ImageResponse`
/// envelope that also carries the status code and headers. The factory is how `downloadImage`
/// builds the requested type — not meant to be called directly.
public protocol ImageDownloadable {
    static func makeDownloadResult(
        image: Image,
        statusCode: Int,
        headers: [String: AnyCodable]
    ) -> Self
}

/// The payload types a `downloadData` call can produce: the bare `Data`, or a `DataResponse`
/// envelope that also carries the status code and headers.
public protocol DataDownloadable {
    static func makeDownloadResult(
        data: Data,
        statusCode: Int,
        headers: [String: AnyCodable]
    ) -> Self
}

extension Image: ImageDownloadable {
    public static func makeDownloadResult(
        image: Image,
        statusCode: Int,
        headers: [String: AnyCodable]
    ) -> Self {
        // Self is the concrete type the caller asked for, and Image is the only case that reaches here.
        // oida:disable:next force_cast
        return image as! Self
    }
}

extension Data: DataDownloadable {
    public static func makeDownloadResult(
        data: Data,
        statusCode: Int,
        headers: [String: AnyCodable]
    ) -> Self {
        return data
    }
}

// @unchecked: immutable struct; the only non-Sendable-provable field is the platform `Image`,
// which is effectively read-only once downloaded.
/// A downloaded image plus the response metadata, for callers that need the status/headers.
public struct ImageResponse: ImageDownloadable, @unchecked Sendable {
    public let statusCode: Int
    public let headers: [String: AnyCodable]
    public let image: Image

    public static func makeDownloadResult(
        image: Image,
        statusCode: Int,
        headers: [String: AnyCodable]
    ) -> ImageResponse {
        ImageResponse(
            statusCode: statusCode,
            headers: headers,
            image: image
        )
    }
}

/// Downloaded data plus the response metadata, for callers that need the status/headers.
public struct DataResponse: DataDownloadable, Sendable {
    public let statusCode: Int
    public let headers: [String: AnyCodable]
    public let data: Data

    public static func makeDownloadResult(
        data: Data,
        statusCode: Int,
        headers: [String: AnyCodable]
    ) -> DataResponse {
        DataResponse(
            statusCode: statusCode,
            headers: headers,
            data: data
        )
    }
}
