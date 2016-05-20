import Foundation

public enum FormDataType {
    case PNG
    case JPG
    case Custom(String)

    var contentType: String {
        switch self {
        case .PNG:
            return "image/png"
        case .JPG:
            return "image/jpeg"
        case .Custom(let value):
            return value
        }
    }
}

public struct FormData {
    let data: NSData
    let parameter: String
    let filename: String
    let type: FormDataType
}