import CoreLocation

/// One-shot approximate location for distance-based discovery. The app asks
/// for reduced accuracy by default (Info.plist) and the server rounds again to
/// ~1 km, so precise positions are never needed or stored.
enum LocationService {
    struct Coordinate: Sendable, Equatable {
        let latitude: Double
        let longitude: Double
    }

    static func approximateCoordinate(timeout: Duration = .seconds(12)) async -> Coordinate? {
        await withTaskGroup(of: Coordinate?.self) { group in
            group.addTask { await firstFix() }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    private static func firstFix() async -> Coordinate? {
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                    return nil
                }
                if let location = update.location {
                    return Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                }
            }
        } catch {
            return nil
        }
        return nil
    }
}
