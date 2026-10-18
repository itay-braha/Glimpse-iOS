import Foundation

/// Remembers what someone agreed to on the welcome screen until they're signed
/// in and it can be recorded on the server (with the document version, as proof).
enum ConsentStore {
    /// Bump with every material change to the Terms or Privacy Policy: members are asked again.
    static let currentVersion = LegalDocument.version

    private static let pendingKey = "consent.pendingVersion"
    private static let acceptedKey = "consent.acceptedVersion"

    static func markPending() {
        UserDefaults.standard.set(currentVersion, forKey: pendingKey)
    }

    static var pendingVersion: String? {
        UserDefaults.standard.string(forKey: pendingKey)
    }

    static func markRecorded(_ version: String) {
        UserDefaults.standard.removeObject(forKey: pendingKey)
        UserDefaults.standard.set(version, forKey: acceptedKey)
    }

    static var acceptedVersion: String? {
        UserDefaults.standard.string(forKey: acceptedKey)
    }

    /// "he" or "en", from the phone's language (what the server writes alerts in).
    static var languageCode: String {
        Locale.preferredLanguages.first?.hasPrefix("he") == true ? "he" : "en"
    }
}
