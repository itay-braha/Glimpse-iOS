import AuthenticationServices
import UIKit

/// Runs Instagram's OAuth consent in a system web sheet, then hands the code to
/// the `social-import` function, which fetches and verifies recent Reels.
@MainActor
enum InstagramImporter {
    enum Failure: Error {
        case cancelled
    }

    /// The system releases neither of these for us while the sheet is up.
    private static var activeSession: ASWebAuthenticationSession?
    private static var activeAnchor: PresentationAnchor?

    static func run(backend: any GlimpseBackend, config: AppConfig?) async throws -> [ProfileVideo] {
        if backend.isDemo {
            return try await backend.importInstagram(code: "demo")
        }
        guard let config, let appID = config.instagramAppID else {
            throw GlimpseError.instagramNotConfigured
        }
        let code = try await authorize(appID: appID, redirectURI: config.instagramRedirectURI)
        return try await backend.importInstagram(code: code)
    }

    private static func authorize(appID: String, redirectURI: String) async throws -> String {
        var components = URLComponents(string: "https://www.instagram.com/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: appID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "instagram_business_basic"),
        ]
        guard let url = components.url else { throw GlimpseError.instagramNotConfigured }

        let anchor = PresentationAnchor()
        activeAnchor = anchor
        defer {
            activeSession = nil
            activeAnchor = nil
        }
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "glimpse") { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: Failure.cancelled)
                } else {
                    continuation.resume(throwing: error ?? Failure.cancelled)
                }
            }
            session.presentationContextProvider = anchor
            session.prefersEphemeralWebBrowserSession = true
            activeSession = session
            session.start()
        }

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let code = items.first(where: { $0.name == "code" })?.value {
            return code
        }
        throw Failure.cancelled
    }
}

private final class PresentationAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        nonisolated(unsafe) var anchor: ASPresentationAnchor?
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            anchor = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
                ?? ASPresentationAnchor(windowScene: scenes[0])
        }
        return anchor!
    }
}
