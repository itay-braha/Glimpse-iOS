import Foundation

struct DialCode: Identifiable, Hashable, Sendable {
    let regionCode: String
    let code: String
    let flag: String
    /// How a mobile number reads once the country code and trunk "0" are gone,
    /// e.g. Israel 54-123-4567 is [2, 3, 4]. Drives the digit slots on sign-in.
    let groups: [Int]
    /// Shortest valid mobile number. Equals `maxDigits` where the length is fixed.
    let minDigits: Int

    init(regionCode: String, code: String, flag: String, groups: [Int], minDigits: Int? = nil) {
        self.regionCode = regionCode
        self.code = code
        self.flag = flag
        self.groups = groups
        self.minDigits = minDigits ?? groups.reduce(0, +)
    }

    var id: String { regionCode }
    var maxDigits: Int { groups.reduce(0, +) }

    /// "Israel", "United States"… in the phone's language.
    var countryName: String {
        Locale.current.localizedString(forRegionCode: regionCode) ?? regionCode
    }

    static let all: [DialCode] = [
        DialCode(regionCode: "US", code: "1", flag: "🇺🇸", groups: [3, 3, 4]),
        DialCode(regionCode: "IL", code: "972", flag: "🇮🇱", groups: [2, 3, 4]),
        DialCode(regionCode: "GB", code: "44", flag: "🇬🇧", groups: [4, 3, 3]),
        DialCode(regionCode: "CA", code: "1", flag: "🇨🇦", groups: [3, 3, 4]),
        DialCode(regionCode: "DE", code: "49", flag: "🇩🇪", groups: [3, 4, 4], minDigits: 10),
        DialCode(regionCode: "FR", code: "33", flag: "🇫🇷", groups: [1, 2, 2, 2, 2]),
        DialCode(regionCode: "ES", code: "34", flag: "🇪🇸", groups: [3, 3, 3]),
        DialCode(regionCode: "IT", code: "39", flag: "🇮🇹", groups: [3, 3, 4], minDigits: 9),
        DialCode(regionCode: "NL", code: "31", flag: "🇳🇱", groups: [1, 4, 4]),
        DialCode(regionCode: "AU", code: "61", flag: "🇦🇺", groups: [3, 3, 3]),
        DialCode(regionCode: "IN", code: "91", flag: "🇮🇳", groups: [5, 5]),
        DialCode(regionCode: "BR", code: "55", flag: "🇧🇷", groups: [2, 5, 4]),
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

    /// Cleans whatever was typed, pasted or autofilled into the national digits the
    /// slots show: no formatting, no "+972" / "00972" prefix, no trunk "0", capped
    /// at the country's length. "+972 54-123-4567" and "054 123 4567" both give "541234567".
    static func nationalDigits(_ raw: String, dialCode: DialCode) -> String {
        var digits = raw.filter { $0.isASCII && $0.isNumber }
        let international = raw.trimmingCharacters(in: .whitespaces).hasPrefix("+")
        if digits.hasPrefix("00" + dialCode.code) {
            digits.removeFirst(2 + dialCode.code.count)
        } else if (international || digits.count > dialCode.maxDigits), digits.hasPrefix(dialCode.code) {
            digits.removeFirst(dialCode.code.count)
        }
        while digits.hasPrefix("0") { digits.removeFirst() }
        return String(digits.prefix(dialCode.maxDigits))
    }

    /// True when the slots hold a complete number for that country.
    static func isComplete(_ national: String, dialCode: DialCode) -> Bool {
        (dialCode.minDigits...dialCode.maxDigits).contains(national.count)
            && e164(dialCode: dialCode.code, national: national) != nil
    }
}
