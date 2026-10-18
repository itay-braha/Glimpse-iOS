import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class GoldModel {
    private(set) var status: GoldStatus = .none
    private(set) var insights: [ClipInsight] = []
    private(set) var videos: [ProfileVideo] = []
    private(set) var hasLoaded = false
    private(set) var isWorking = false
    var errorMessage: String?

    func load(using backend: any GlimpseBackend) async {
        defer { hasLoaded = true }
        status = (try? await backend.goldStatus()) ?? .none
        guard status.isGold else { return }
        videos = (try? await backend.fetchMyVideos()) ?? []
        insights = (try? await backend.clipInsights()) ?? []
    }

    func startSpotlight(using backend: any GlimpseBackend) async {
        await run(using: backend) { _ = try await backend.startSpotlight() }
    }

    /// Looks the city up, then starts the trip there.
    func startTrip(to city: String, days: Int, using backend: any GlimpseBackend) async {
        let name = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        await run(using: backend) {
            let coordinate: CLLocationCoordinate2D
            if backend.isDemo {
                coordinate = CLLocationCoordinate2D(latitude: 31.77, longitude: 35.21)
            } else {
                let places = try await CLGeocoder().geocodeAddressString(name)
                guard let found = places.first?.location?.coordinate else {
                    throw GlimpseError.message("We couldn't find \(name). Try the city's full name.")
                }
                coordinate = found
            }
            _ = try await backend.setTravel(latitude: coordinate.latitude, longitude: coordinate.longitude, city: name, days: days)
        }
    }

    func endTrip(using backend: any GlimpseBackend) async {
        await run(using: backend) { try await backend.endTravel() }
    }

    func insight(for video: ProfileVideo) -> ClipInsight? {
        insights.first { $0.videoID == video.id }
    }

    private func run(using backend: any GlimpseBackend, _ work: () async throws -> Void) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await work()
            errorMessage = nil
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
        status = (try? await backend.goldStatus()) ?? status
    }
}
