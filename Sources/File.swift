import Foundation

public enum FileType {
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

public struct File {
    let data: NSData
    let parameter: String
    let filename: String
    let type: FileType

    var formData: NSData {
        var body = ""
        body += "--\(Networking.Boundary)\r\n"
        body += "Content-Disposition: form-data; name=\"\(self.parameter)\""
        body += "; filename=\"\(self.filename)\"\r\n"
        body += "Content-Type: \(self.type.contentType)\r\n\r\n"

        let bodyData = NSMutableData()
        bodyData.appendData(body.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        bodyData.appendData(self.data)

        return bodyData.copy() as! NSData
    }
}