import Foundation

/// Parses the timestamp shapes Postgres, PostgREST and Realtime emit:
/// "2026-10-15T06:15:05.123456+00:00", "2026-10-15 06:15:05+00", "2026-10-15T06:15:05Z", "2026-10-15".
enum FlexibleDate {
    static func parse(_ raw: String) -> Date? {
        var value = raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "T")

        guard let timeStart = value.firstIndex(of: "T") else {
            return try? Date(value, strategy: Date.ISO8601FormatStyle().year().month().day())
        }

        // Normalise fractional seconds to milliseconds.
        if let dot = value[timeStart...].firstIndex(of: ".") {
            var end = value.index(after: dot)
            while end < value.endIndex, value[end].isNumber {
                end = value.index(after: end)
            }
            let digits = String(value[value.index(after: dot)..<end].prefix(3))
            let millis = digits.padding(toLength: 3, withPad: "0", startingAt: 0)
            value = String(value[..<dot]) + "." + millis + String(value[end...])
        }

        let timePart = value[value.index(after: timeStart)...]
        if !(timePart.contains("+") || timePart.contains("-") || timePart.contains("Z")) {
            value += "Z"
        } else if let shortOffset = try? Regex("[+-][0-9]{2}$"), value.firstMatch(of: shortOffset) != nil {
            value += ":00"
        }

        if let date = try? Date(value, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
            return date
        }
        return try? Date(value, strategy: Date.ISO8601FormatStyle())
    }
}

extension JSONDecoder {
    static func glimpse() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = FlexibleDate.parse(raw) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognised date \(raw)")
            }
            return date
        }
        return decoder
    }
}
