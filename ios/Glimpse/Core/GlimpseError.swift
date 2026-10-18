import Foundation

enum GlimpseError: LocalizedError, Equatable {
    case notSignedIn
    case invalidPhoneNumber
    case invalidCode
    case deviceBlocked
    case deviceUnverified
    case cameraUnavailable
    /// Not a public Instagram post/Reel or TikTok video.
    case invalidEmbedLink
    case videoAlreadyAdded
    /// Stories expire, so they're uploaded rather than linked.
    case storyLink
    /// Filmed or posted more than 12 months ago.
    case clipTooOld
    /// Links sit on top of at least one clip Glimpse hosts.
    case hostedFirst
    /// The last own clip can't be removed.
    case lastHostedClip
    /// Over the 20 MB upload cap even after compression.
    case videoTooLarge
    /// Free daily likes are used up (Glimpse+ or waiting lifts it).
    case outOfLikes
    /// The free daily "who liked you" reveal is used up.
    /// Abuse protection: too many actions in a short time.
    case rateLimited
    /// Daily limit on new profiles seen.
    case outOfViews
    /// The account is on a break (vacation mode).
    case paused
    case freezeLimit
    case pinLimit
    case goldRequired
    case ringLimit
    case videoCallsOff
    case spotlightUsed
    case rewindLimit
    case cityNotOpen
    case plusRequired
    case secondChanceLimit
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn: "Your session ended. Sign in again."
        case .invalidPhoneNumber: "That doesn't look like a mobile number."
        case .invalidCode: "That code didn't work. Check it and try again."
        case .deviceBlocked: "This device can't be used for Glimpse."
        case .deviceUnverified: "We couldn't verify this device. Try again on a real iPhone."
        case .cameraUnavailable: "The camera isn't available on this device."
        case .invalidEmbedLink: "That link isn't a public Instagram post or Reel, or a TikTok video."
        case .videoAlreadyAdded: "That video is already on your profile."
        case .hostedFirst: "Add a clip of your own first. Linked posts sit on top of it."
        case .lastHostedClip: "Keep at least one clip of your own. Add another before removing this one."
        case .clipTooOld: "That clip is more than a year old. Pick something from the last 12 months."
        case .storyLink: "Stories disappear after 24 hours. Save it to your camera roll and upload it instead."
        case .videoTooLarge: "That video is over 20 MB. Try a shorter clip."
        case .outOfLikes: "You're out of likes for now."
        case .rateLimited: "Whoa, slow down a little. Try again in a minute."
        case .outOfViews: "You've seen today's glimpses."
        case .paused: "Your profile is on a break. Resume it to keep exploring."
        case .freezeLimit: "You've used your free freeze. Glimpse+ protects up to 3 connections."
        case .pinLimit: "You can pin up to 3 conversations. Unpin one first."
        case .goldRequired: "That's part of Glimpse Gold."
        case .ringLimit: "Give it a little time before calling again."
        case .videoCallsOff: "Turn on video calls in Settings first."
        case .spotlightUsed: "Your next Spotlight is ready a week after the last one."
        case .rewindLimit: "You've used today's 5 rewinds."
        case .cityNotOpen: "Glimpse isn't open in that city yet."
        case .plusRequired: "That's part of Glimpse+."
        case .secondChanceLimit: "You can send one second chance a week."
        case let .message(text): text
        }
    }

    /// Best-effort human message for any error thrown by a backend call.
    static func describe(_ error: any Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return "Something went wrong. Try again."
    }
}
