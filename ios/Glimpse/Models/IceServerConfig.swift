import Foundation

struct IceServerConfig: Codable, Hashable, Sendable {
    var urls: [String]
    var username: String?
    var credential: String?

    init(urls: [String], username: String? = nil, credential: String? = nil) {
        self.urls = urls
        self.username = username
        self.credential = credential
    }

    // Cloudflare / WebRTC allow "urls" to be a single string or a list.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let list = try? container.decode([String].self, forKey: .urls) {
            urls = list
        } else {
            urls = [try container.decode(String.self, forKey: .urls)]
        }
        username = try container.decodeIfPresent(String.self, forKey: .username)
        credential = try container.decodeIfPresent(String.self, forKey: .credential)
    }

    enum CodingKeys: String, CodingKey {
        case urls
        case username
        case credential
    }
}
