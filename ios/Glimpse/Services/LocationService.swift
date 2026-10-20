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

    /// A precise fix for the coffee-deal check-in ("are you at the café?"). Asks iOS for
    /// temporary full accuracy with the DealCheckIn purpose. The position is only used on
    /// the phone to compare with the venue; the server gets a distance band, never this.
    static func preciseCoordinate(timeout: Duration = .seconds(8)) async -> Coordinate? {
        await withTaskGroup(of: Coordinate?.self) { group in
            group.addTask { await preciseFix() }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    /// Straight-line metres between two points.
    static func meters(from a: Coordinate, to b: Coordinate) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    private static func preciseFix() async -> Coordinate? {
        let session = CLServiceSession(authorization: .whenInUse, fullAccuracyPurposeKey: "DealCheckIn")
        defer { session.invalidate() }
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                    return nil
                }
                // Wait for a fix good enough to tell "at the café" from "down the street".
                if let location = update.location, location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 150 {
                    return Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                }
            }
        } catch {
            return nil
        }
        return nil
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
