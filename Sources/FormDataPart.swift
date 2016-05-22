import Foundation

public enum FormDataPartType {
    case Data
    case PNG
    case JPG
    case Custom(String)

    var contentType: String {
        switch self {
        case .Data:
            return "application/octet-stream"
        case .PNG:
            return "image/png"
        case .JPG:
            return "image/jpeg"
        case .Custom(let value):
            return value
        }
    }
}

public struct FormDataPart {
    private let data: NSData
    private let parameterName: String
    private let filename: String
    private let type: FormDataPartType
    var boundary: String = ""

    var formData: NSData {
        var body = ""
        body += "--\(boundary)\r\n"
        body += "Content-Disposition: form-data; "
        body += "name=\"\(self.parameterName)\"; "
        body += "filename=\"\(self.filename)\"\r\n"
        body += "Content-Type: \(self.type.contentType)\r\n\r\n"

        let bodyData = NSMutableData()
        bodyData.appendData(body.dataUsingEncoding(NSUTF8StringEncoding)!)
        bodyData.appendData(self.data)
        bodyData.appendData("\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)

        return bodyData
    }

    public init(type: FormDataPartType = .Data, data: NSData, parameterName: String, filename: String) {
        self.type = type
        self.data = data
        self.parameterName = parameterName
        self.filename = filename
    }
}
