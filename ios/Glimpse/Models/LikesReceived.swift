import Foundation

/// People who liked me and are waiting for an answer.
struct LikesReceived: Codable, Hashable, Sendable {
    var total: Int
    var isPlus: Bool
    var freeRevealsLeft: Int?
    var items: [ReceivedLike]

    static let empty = LikesReceived(total: 0, isPlus: false, freeRevealsLeft: 0, items: [])

    enum CodingKeys: String, CodingKey {
        case total
        case isPlus = "is_plus"
        case freeRevealsLeft = "free_reveals_left"
        case items
    }
}
