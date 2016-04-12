import Foundation

extension String {
    func encodeUTF8() -> String? {
        if let _ = NSURL(string: self) {
            return self
        }

        let optionalLastComponent = self.characters.split { $0 == "/" }.last
        if let lastComponent = optionalLastComponent {
            let lastComponentAsString = lastComponent.map { String($0) }.reduce("", combine: +)
            if let rangeOfLastComponent = self.rangeOfString(lastComponentAsString) {
                let stringWithoutLastComponent = self.substringToIndex(rangeOfLastComponent.startIndex)
                if let lastComponentEncoded = lastComponentAsString.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.alphanumericCharacterSet()) {
                    let encodedString = stringWithoutLastComponent + lastComponentEncoded
                    return encodedString
                }
            }
        }

        return nil;
    }
}
