import Foundation

/// In-app legal texts (there is no website). Drafts: have them reviewed by a
/// lawyer and set `contactEmail` before launch.
enum LegalDocument: String, Identifiable, CaseIterable {
    case terms
    case privacy
    case communityRules

    static let contactEmail = "support@glimpse.invalid"
    static let lastUpdated = "October 15, 2026"

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
    You can hold up to 20 active connections. When you approve a new match while at 20, your least active connection is ended automatically. Glimpse may adjust how often profiles are shown based on how members treat each other.

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
    **Content:** videos you record or import, and messages you send.
    **Approximate location:** rounded to about 1 km, used only to show people nearby and distances. Your exact location is never stored.
    **Device integrity:** Apple DeviceCheck signals that help keep banned accounts off Glimpse. These don't identify you personally.
    **Usage and diagnostics:** basic in-app events and crash reports, used to keep Glimpse working.

    ## How we use it
    To run your profile, show you people, enforce the 20-connection limit, keep the community safe, send the notifications you allow, and improve the app. We do not sell your personal information and we do not show third-party ads.

    ## Who can see what
    Your profile and videos are visible to people Glimpse shows you to and to your matches. Messages are visible only to you and the person you're talking to. Reports you file are confidential.

    ## Service providers
    We use Supabase to host data and Apple for push notifications, DeviceCheck and payments. If you connect Instagram, we receive the videos you choose to import from Meta.

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
