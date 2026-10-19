import Foundation

/// What onboarding collects before the first video.
struct ProfileDraft: Sendable {
    var displayName: String
    var birthdate: Date
    var gender: Gender
    var interestedIn: Set<Gender>
    var city: String
    var bio: String
    var height: HeightSetting
}
