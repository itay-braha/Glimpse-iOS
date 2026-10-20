import Foundation

/// The server's answer to "would a kind goodbye fit here?". It decides, so the app
/// never shows it in a chat with a report, too often, or twice in one chat.
struct GoodbyeOffer: Codable, Identifiable, Hashable, Sendable {
    let show: Bool
    var promptID: UUID?
    var trigger: GoodbyeTrigger?

    var id: String { promptID?.uuidString ?? "none" }

    static let none = GoodbyeOffer(show: false)

    enum CodingKeys: String, CodingKey {
        case show
        case promptID = "prompt_id"
        case trigger
    }
}
