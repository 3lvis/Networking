import Foundation

extension Networking {
    // Flattens a flat `Encodable` into `[String: String]` for form bodies and query strings.
    //
    // Bridges through JSON so any `Encodable` works, then re-decodes each value as a scalar — this is
    // what keeps `Bool` honest: `JSONSerialization` would surface it as an `NSNumber` that stringifies
    // to "1", whereas decoding `Bool` directly yields "true"/"false". Nested objects/arrays decode to
    // neither scalar and throw, since `application/x-www-form-urlencoded` has no canonical nesting.
    func formFields(from value: some Encodable) throws -> [String: String] {
        let data = try Self.requestBodyEncoder.encode(value)
        let scalars = try JSONDecoder().decode([String: FormScalar].self, from: data)
        return scalars.mapValues(\.stringValue)
    }
}

// Decodes a single form/query value, preserving the JSON scalar type so it stringifies the way a human
// wrote it. Order matters: `Bool` before `Int` (so `true` isn't read as a number) and `Int` before
// `Double` (so `2` stays "2", not "2.0"); `JSONDecoder` is strict about JSON types, so each `try?`
// only succeeds for its real kind.
private enum FormScalar: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "form/query values must be String, Int, Double, or Bool — nested objects and arrays aren't supported")
        }
    }

    var stringValue: String {
        switch self {
        case let .string(value): return value
        case let .int(value): return String(value)
        case let .double(value): return String(value)
        case let .bool(value): return String(value)
        }
    }
}
