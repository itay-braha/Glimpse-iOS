import CryptoKit
import Foundation

/// Disk cache for feed clips. The first view streams from the network while the
/// file downloads in the background; every later view (and the next cards,
/// via `prefetch`) plays from local storage.
actor VideoCache {
    static let shared = VideoCache()

    private let directory: URL
    private var inFlight: [String: Task<URL?, Never>] = [:]
    private let maxBytes = 400 * 1024 * 1024

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appending(path: "glimpse-video", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Returns a local file if cached, otherwise the remote URL (and starts caching it).
    func playableURL(for key: String, remote: URL) -> URL {
        let local = fileURL(for: key)
        if FileManager.default.fileExists(atPath: local.path()) {
            return local
        }
        startDownload(key: key, remote: remote)
        return remote
    }

    func prefetch(key: String, remote: URL) {
        startDownload(key: key, remote: remote)
    }

    private func startDownload(key: String, remote: URL) {
        let local = fileURL(for: key)
        guard inFlight[key] == nil, !FileManager.default.fileExists(atPath: local.path()) else { return }
        inFlight[key] = Task.detached(priority: .utility) {
            guard let result = try? await URLSession.shared.download(from: remote),
                  ((result.1 as? HTTPURLResponse)?.statusCode ?? 200) < 400
            else { return nil }
            try? FileManager.default.moveItem(at: result.0, to: local)
            return local
        }
        Task { await self.finish(key) }
    }

    private func finish(_ key: String) async {
        _ = await inFlight[key]?.value
        inFlight[key] = nil
        trimIfNeeded()
    }

    private func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appending(path: "\(digest.prefix(32)).mp4")
    }

    private func trimIfNeeded() {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentAccessDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: Array(keys)
        ) else { return }

        var entries = files.compactMap { url -> (URL, Int, Date)? in
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            return (url, values.fileSize ?? 0, values.contentAccessDate ?? .distantPast)
        }
        var total = entries.reduce(0) { $0 + $1.1 }
        guard total > maxBytes else { return }

        entries.sort { $0.2 < $1.2 }
        for (url, size, _) in entries where total > maxBytes {
            try? FileManager.default.removeItem(at: url)
            total -= size
        }
    }
}
