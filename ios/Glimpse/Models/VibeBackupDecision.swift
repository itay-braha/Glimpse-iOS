import Foundation

/// What to do with this phone's backup copy of the other person's video
/// (mirrors `vibe_backup_decision`).
enum VibeBackupDecision: String, Codable, Sendable {
    /// Their own recording is missing (or the call was reported): send ours.
    case upload
    /// Their own recording arrived: the backup isn't needed.
    case discard
    /// Too early to tell; ask again later.
    case wait
}
