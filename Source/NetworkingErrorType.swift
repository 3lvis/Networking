/**
 Categorizes a networking error.
 - `Client:` The 4xx class of status code is intended for cases in which the client seems to have erred.
 - `Server:` Response status codes beginning with the digit "5" indicate cases in which the server is aware that it has erred or is incapable of performing the request.
 */
public enum NetworkingErrorType: Equatable {
    case Client(Int), Server(Int)
}

public func ==(a: NetworkingErrorType, b: NetworkingErrorType) -> Bool {
    switch (a, b) {
    case (.Client(let a),   .Client(let b))   where a == b: return true
    case (.Server(let a), .Server(let b)) where a == b: return true
    default: return false
    }
}
