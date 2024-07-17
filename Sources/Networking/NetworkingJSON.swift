import Foundation

public struct NetworkingJSON: Decodable {
    public let headers: [String: AnyCodable]
    public let body: [String: AnyCodable]
}

public struct AnyCodable: Decodable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Bool.self) {
            self.value = value
        } else if let value = try? container.decode(Int.self) {
            self.value = value
        } else if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode([String: AnyCodable].self) {
            self.value = value
        } else if let value = try? container.decode([AnyCodable].self) {
            self.value = value
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "The container contains nothing serializable")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let value = self.value as? Bool {
            try container.encode(value)
        } else if let value = self.value as? Int {
            try container.encode(value)
        } else if let value = self.value as? Double {
            try container.encode(value)
        } else if let value = self.value as? String {
            try container.encode(value)
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "The value cannot be encoded"))
        }
    }
}

extension AnyCodable: Hashable {
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        return String(describing: lhs.value) == String(describing: rhs.value)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }
}
