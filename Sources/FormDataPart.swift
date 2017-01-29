import Foundation

public enum FormDataPartType {
    case data
    case png
    case jpg
    case custom(String)

    var contentType: String {
        switch self {
        case .data:
            return "application/octet-stream"
        case .png:
            return "image/png"
        case .jpg:
            return "image/jpeg"
        case .custom(let value):
            return value
        }
    }
}

public struct FormDataPart {
    fileprivate let data: Data
    fileprivate let parameterName: String
    fileprivate let filename: String?
    fileprivate let type: FormDataPartType
    var boundary: String = ""

    var formData: Data {
        var body = ""
        body += "--\(boundary)\r\n"
        body += "Content-Disposition: form-data; "
        body += "name=\"\(self.parameterName)\""
        if let filename = self.filename {
            body += "; filename=\"\(filename)\""
        }
        body += "\r\n"
        body += "Content-Type: \(self.type.contentType)\r\n\r\n"

        var bodyData = Data()
        bodyData.append(body.data(using: .utf8)!)
        bodyData.append(self.data)
        bodyData.append("\r\n".data(using: .utf8)!)

        return bodyData as Data
    }

    public init(type: FormDataPartType = .data, data: Data, parameterName: String, filename: String? = nil) {
        self.type = type
        self.data = data
        self.parameterName = parameterName
        self.filename = filename
    }
}
