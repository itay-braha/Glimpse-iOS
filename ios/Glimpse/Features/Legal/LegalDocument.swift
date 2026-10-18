import Foundation

/// In-app legal texts (there is no website). Drafts: have them reviewed by a
/// lawyer and set `contactEmail` before launch.
enum LegalDocument: String, Identifiable, CaseIterable {
    case terms
    case privacy
    case communityRules

    static let contactEmail = "support@glimpse.invalid"
    static let lastUpdated = "October 18, 2026"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: "Terms of Service"
        case .privacy: "Privacy Policy"
        case .communityRules: "Community Rules"
        }
    }

    /// Lightweight markdown: "## " lines are headings, blank lines split paragraphs, **bold** inline.
    var body: String {
        switch self {
        case .terms: Self.termsText
        case .privacy: Self.privacyText
        case .communityRules: Self.communityText
        }
    }

    private static let termsText = """
    Last updated \(lastUpdated)

    ## Who can use Glimpse
    You must be at least 18 years old, legally able to enter this agreement, and not barred from using dating services. One account per person. You must use a mobile phone number that belongs to you.

    ## Your content
    You own the videos and messages you share. You give Glimpse a license to host, display and distribute them inside the app so the service can work. Only share content you have the right to share, and only content that shows you.

    ## How Glimpse works
    You can hold up to 15 active connections. When you approve a new match while at 15, your least active connection is ended automatically. Glimpse may adjust how often profiles are shown based on how members treat each other.

    ## Safety and enforcement
    We may hide content, suspend or close accounts, and block devices that break these terms or the Community Rules. Serious violations can result in a permanent ban from the service on the device used.

    ## Glimpse+
    Glimpse+ is an auto-renewing subscription billed through your Apple ID. It renews unless cancelled at least 24 hours before the period ends. Manage or cancel it in your Apple ID settings. Glimpse+ never increases the 20-connection limit.

    ## Meeting people
    Glimpse does not run criminal background checks. Use good judgment, meet in public places and tell a friend where you're going. Glimpse isn't responsible for the conduct of members on or off the app.

    ## Deleting your account
    You can delete your account at any time in Settings. Deletion removes your profile, videos and messages from Glimpse.

    ## Contact
    Questions about these terms: \(contactEmail)
    """

    private static let privacyText = """
    Last updated \(lastUpdated)

    ## What we collect
    **Account:** your phone number (to verify you're a real person) and the profile details you enter.
    **Content:** videos you record or import, and messages you send (text, voice and video notes). If you delete a message, it disappears from the chat, but a copy is kept privately for 30 days (longer if the conversation is reported) so the safety team can review reports.
    **Vibe Check safety recordings:** during a 3-Minute Vibe Check, each phone records what its own camera and microphone send, plus a low-quality copy of the video it receives, and uploads them to Glimpse's private storage while the call is running. You agree to this before every call. Recordings are stored privately for 30 days and deleted after that. Nobody watches them unless one of you reports the call; then only Glimpse's safety team does, and they're kept until the report is closed. Screenshots and screen-recording attempts during a call are logged.
    **Approximate location:** rounded to about 1 km, used only to show people nearby and distances. Your exact location is never stored.
    **Device integrity:** Apple DeviceCheck signals that help keep banned accounts off Glimpse. These don't identify you personally.
    **Usage and diagnostics:** basic in-app events and crash reports, used to keep Glimpse working.

    ## How we use it
    To run your profile, show you people, enforce the 15-connection limit, keep the community safe, send the notifications you allow, and improve the app. We do not show third-party ads.

    ## Optional: research and model training
    Both are off unless you turn them on in Settings, and you can turn them off at any time.
    **Help improve matching:** your activity (likes, passes, watch time, match outcomes and conversation rhythm, never message text, videos, your name, phone number or exact location) may be used under a random code instead of your identity to train Glimpse's own matching and safety models.
    **Share anonymous trends:** statistics about groups of at least 20 members (for example, like rates by age range and region) may be shared with research or business partners. Nothing about you individually is shared, and we never sell your personal information.

    ## Who can see what
    Your profile and videos are visible to people Glimpse shows you to and to your matches. Messages are visible only to you and the person you're talking to. Vibe Check calls can't be screenshotted or screen-recorded inside Glimpse, and their safety recordings are never shown to the other person or anyone else outside the safety team. Reports you file are confidential.

    ## Service providers
    We use Supabase to host data and Apple for push notifications, DeviceCheck and payments. If you link a public Instagram or TikTok post, it plays through that platform's own player, and tapping it can take you there.

    ## Retention and deletion
    Deleting your account removes your profile, videos, messages and matches. Limited safety records (for example, that a device was banned) may be kept to prevent abuse.

    ## Your choices
    You can edit your profile, turn off location or notifications in iOS Settings, export or correct your data by contacting us, and delete your account in Settings.

    ## Contact
    Privacy questions: \(contactEmail)
    """

    private static let communityText = """
    Glimpse is a dating club built on respect and real effort. These rules keep it that way.

    ## Be real
    Only post videos of yourself, from your own life. No impersonation, no stolen content, no misleading edits.

    ## Be kind
    No harassment, hate, threats or pressure. "No" means no, including no reply.

    ## Show up
    Matches are limited for a reason. Talk to the people you match with, and end connections you're not interested in instead of ghosting.

    ## Keep it appropriate
    No nudity or sexual content in videos. No content involving minors, ever.

    ## No selling, no scams
    No promotion, solicitation, crypto pitches or requests for money.

    ## Report what feels wrong
    Reports are confidential and reviewed. Reporting someone also blocks them for you. False or retaliatory reports are a violation too.
    """
}
