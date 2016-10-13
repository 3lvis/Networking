import Foundation

extension String {

    func encodeUTF8() -> String? {
        if let _ = URL(string: self) {
            return self
        }

        let optionalLastComponent = self.characters.split { $0 == "/" }.last
        if let lastComponent = optionalLastComponent {
            let lastComponentAsString = lastComponent.map { String($0) }.reduce("", +)
            if let rangeOfLastComponent = self.range(of: lastComponentAsString) {
                let stringWithoutLastComponent = self.substring(to: rangeOfLastComponent.lowerBound)
                if let lastComponentEncoded = lastComponentAsString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    let encodedString = stringWithoutLastComponent + lastComponentEncoded
                    return encodedString
                }
            }
        }

        return nil
    }
}
