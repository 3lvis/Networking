import Foundation

public extension NSError {
    public func networkingErrorType() -> NetworkingErrorType {
        if self.code >= 400 && self.code < 500 {
            return .Client(self.code)
        } else {
            return .Server(self.code)
        }
    }
}
