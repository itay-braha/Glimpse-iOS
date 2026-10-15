import Foundation

/// Build-time configuration injected through Config/*.xcconfig → Info.plist.
struct AppConfig: Sendable {
    let supabaseURL: URL
    let supabaseKey: String

    /// `nil` when the build has no Supabase project configured (demo mode).
    static func load(from bundle: Bundle = .main) -> AppConfig? {
        func value(_ key: String) -> String? {
            guard let raw = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed.contains("$(") ? nil : trimmed
        }

        guard let host = value("GlimpseSupabaseHost"),
              let key = value("GlimpseSupabaseKey"),
              let url = URL(string: "https://\(host)")
        else { return nil }

        return AppConfig(supabaseURL: url, supabaseKey: key)
    }
}
