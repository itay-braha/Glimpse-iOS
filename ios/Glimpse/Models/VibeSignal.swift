import Foundation

/// WebRTC signaling message exchanged over the private Realtime channel.
struct VibeSignal: Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case ready
        case offer
        case answer
        case candidate
        case capture
        case screenshot
        case hangup
    }

    var kind: Kind
    var sender: String
    var sdp: String?
    var sdpMLineIndex: Int32?
    var sdpMid: String?
    var flag: Bool?

    enum CodingKeys: String, CodingKey {
        case kind
        case sender
        case sdp
        case sdpMLineIndex = "sdp_mline_index"
        case sdpMid = "sdp_mid"
        case flag
    }
}
