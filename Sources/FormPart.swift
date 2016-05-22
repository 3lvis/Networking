import Foundation

public enum FormPartType {
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

public struct FormPart {
    let data: NSData
    let parameterName: String
    let filename: String
    let type: FormPartType

    var formData: NSData {
        var body = ""
        body += "--\(Networking.Boundary)\r\n"
        body += "Content-Disposition: form-data; "
        body += "name=\"\(self.parameterName)\"; "
        body += "filename=\"\(self.filename)\"\r\n"
        body += "Content-Type: \(self.type.contentType)\r\n\r\n"

        let bodyData = NSMutableData()
        bodyData.appendData(body.dataUsingEncoding(NSUTF8StringEncoding)!)

        let string = NSString(data: bodyData, encoding: NSUTF8StringEncoding)!
        print(string)

        bodyData.appendData(self.data)
        bodyData.appendData("\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)

        return bodyData
    }

    public init(data: NSData, parameterName: String, filename: String, type: FormPartType) {
        self.data = data
        self.parameterName = parameterName
        self.filename = filename
        self.type = type
    }
}
