import Foundation

struct DialCode: Identifiable, Hashable, Sendable {
    let regionCode: String
    let code: String
    let flag: String

    var id: String { regionCode }

    static let all: [DialCode] = [
        DialCode(regionCode: "US", code: "1", flag: "🇺🇸"),
        DialCode(regionCode: "IL", code: "972", flag: "🇮🇱"),
        DialCode(regionCode: "GB", code: "44", flag: "🇬🇧"),
        DialCode(regionCode: "CA", code: "1", flag: "🇨🇦"),
        DialCode(regionCode: "DE", code: "49", flag: "🇩🇪"),
        DialCode(regionCode: "FR", code: "33", flag: "🇫🇷"),
        DialCode(regionCode: "ES", code: "34", flag: "🇪🇸"),
        DialCode(regionCode: "IT", code: "39", flag: "🇮🇹"),
        DialCode(regionCode: "NL", code: "31", flag: "🇳🇱"),
        DialCode(regionCode: "AU", code: "61", flag: "🇦🇺"),
        DialCode(regionCode: "IN", code: "91", flag: "🇮🇳"),
        DialCode(regionCode: "BR", code: "55", flag: "🇧🇷"),
    ]

    static var current: DialCode {
        let region = Locale.current.region?.identifier ?? "US"
        return all.first { $0.regionCode == region } ?? all[0]
    }
}

enum PhoneNumber {
    /// Builds an E.164 number ("+972541234567") from a dial code and the national
    /// number as typed. Drops formatting and a leading trunk "0".
    static func e164(dialCode: String, national: String) -> String? {
        var digits = national.filter(\.isNumber)
        if digits.hasPrefix("0") { digits.removeFirst() }
        let full = dialCode.filter(\.isNumber) + digits
        guard (8...15).contains(full.count), digits.count >= 6 else { return nil }
        return "+" + full
    }
}
