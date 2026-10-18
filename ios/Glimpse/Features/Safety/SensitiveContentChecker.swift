import Foundation
import Observation
import SensitiveContentAnalysis

/// On-device nudity detection with Apple's SensitiveContentAnalysis (no cloud, no cost).
///
/// Apple runs the analysis only on phones where the person turned on Sensitive Content
/// Warning (Settings → Privacy & Security) or Communication Safety (Screen Time); for
/// everyone else `analysisPolicy` is `.disabled` and nothing is analyzed. So this is a
/// protection people opt into on their own phone, on top of Glimpse's reporting,
/// review and moderation. It needs the
/// `com.apple.developer.sensitivecontentanalysis.client` entitlement.
///
/// The analyzer only reads local files: remote videos are downloaded to a temporary
/// file first, analyzed, and the file is removed. Results are cached per URL.
@MainActor
@Observable
final class SensitiveContentChecker {
    static let shared = SensitiveContentChecker()

    private let analyzer = SCSensitivityAnalyzer()
    private var cache: [String: Bool] = [:]

    /// True when this phone's owner has turned the feature on (and the entitlement is present).
    var isAvailable: Bool { analyzer.analysisPolicy != .disabled }

    /// `.descriptiveInterventions` (Communication Safety) asks for more explanatory wording.
    var wantsDescriptiveInterventions: Bool { analyzer.analysisPolicy == .descriptiveInterventions }

    /// Checks a video by its remote address: downloads it to a temporary local file first.
    func isSensitive(remoteURLString: String) async throws -> Bool {
        guard let url = URL(string: remoteURLString) else { return false }
        return try await isSensitive(url)
    }

    /// Checks a local or remote video. False when analysis is off on this phone.
    func isSensitive(_ url: URL) async throws -> Bool {
        guard isAvailable else { return false }
        let key = url.absoluteString
        if let known = cache[key] { return known }

        var temporary: URL?
        defer { if let temporary { try? FileManager.default.removeItem(at: temporary) } }
        let local: URL
        if url.isFileURL {
            local = url
        } else {
            local = try await Self.download(url)
            temporary = local
        }

        let sensitive = try await Self.analyze(local)
        cache[key] = sensitive
        return sensitive
    }

    /// Runs off the main actor with its own analyzer, so nothing non-Sendable crosses actors.
    private nonisolated static func analyze(_ local: URL) async throws -> Bool {
        let handler = SCSensitivityAnalyzer().videoAnalysis(forFileAt: local)
        return try await handler.hasSensitiveContent().isSensitive
    }

    /// The analyzer can't read remote URLs: fetch the bytes into a temporary .mp4 file.
    private nonisolated static func download(_ url: URL) async throws -> URL {
        let (downloaded, response) = try await URLSession.shared.download(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let destination = FileManager.default.temporaryDirectory
            .appending(path: "sca-\(UUID().uuidString).\(url.pathExtension.isEmpty ? "mp4" : url.pathExtension)")
        try FileManager.default.moveItem(at: downloaded, to: destination)
        return destination
    }
}
