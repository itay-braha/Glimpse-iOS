import Foundation
import Observation

/// Coffee deals: the list near me, and the walk-in flow (are you there? → live pass →
/// staff tap Redeem). The phone does the "are you there" check itself; only "near" and
/// a distance band are sent.
@MainActor
@Observable
final class DealsModel {
    enum Step: Equatable {
        case list
        case checking(Deal)
        /// Couldn't confirm from here: "Are you at <place>?"
        case confirm(Deal, DistanceBand)
        /// "I'm somewhere else": pick the place you're at.
        case choose(Deal)
        case pass(Deal, DealPass)
        case unavailable(DealOpenResult)
        case redeemed(Deal, Date)
    }

    private(set) var deals: [Deal] = []
    private(set) var hasLoaded = false
    var step: Step = .list
    var errorMessage: String?
    private var here: LocationService.Coordinate?
    private var viewedLogged: Set<UUID> = []

    var availableCount: Int { deals.filter { $0.state == .available }.count }

    func load(using backend: any GlimpseBackend) async {
        do {
            deals = try await backend.dealsNear()
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
        hasLoaded = true
    }

    /// Counted once a day per deal on the server; here once per screen.
    func logViews(using backend: any GlimpseBackend) async {
        for deal in deals where !viewedLogged.contains(deal.id) {
            viewedLogged.insert(deal.id)
            await backend.logDeal(deal.id, kind: .viewed, near: nil, band: nil)
        }
    }

    /// Tapped a deal: check whether we're there, then open the pass or ask.
    func start(_ deal: Deal, using backend: any GlimpseBackend, checkLocation: Bool) async {
        step = .checking(deal)
        if checkLocation, here == nil {
            here = await LocationService.preciseCoordinate()
        }
        let meters = metersTo(deal)
        let band = DistanceBand(meters: meters)
        if let meters, meters <= DistanceBand.nearMeters {
            await open(deal, near: true, band: band, using: backend)
        } else {
            step = .confirm(deal, band)
        }
    }

    /// "Yes, I'm here" (we couldn't tell, or the phone thinks otherwise).
    func confirmHere(_ deal: Deal, band: DistanceBand, using backend: any GlimpseBackend) async {
        await open(deal, near: band == .unknown ? nil : false, band: band, using: backend)
    }

    func notHere(_ deal: Deal, band: DistanceBand, using backend: any GlimpseBackend) async {
        await backend.logDeal(deal.id, kind: .notHere, near: band == .unknown ? nil : false, band: band)
        step = .choose(deal)
    }

    func choose(_ deal: Deal, using backend: any GlimpseBackend) async {
        let meters = metersTo(deal)
        let band = DistanceBand(meters: meters)
        await backend.logDeal(deal.id, kind: .choseOther, near: meters.map { $0 <= DistanceBand.nearMeters }, band: band)
        await open(deal, near: meters.map { $0 <= DistanceBand.nearMeters }, band: band, using: backend)
    }

    /// Other places with deals, nearest to where the phone is (or to my usual area).
    func otherPlaces(than deal: Deal) -> [Deal] {
        deals.filter { $0.id != deal.id && $0.state == .available }
            .sorted { (metersTo($0) ?? ($0.distanceKm ?? 999) * 1_000) < (metersTo($1) ?? ($1.distanceKm ?? 999) * 1_000) }
    }

    func redeem(_ deal: Deal, pass: DealPass, using backend: any GlimpseBackend) async {
        do {
            let result = try await backend.redeemDeal(passID: pass.id)
            switch result.status {
            case .redeemed, .available:
                step = .redeemed(deal, result.redeemedAt ?? .now)
            case .soldOut:
                step = .unavailable(DealOpenResult(status: .soldOut, deal: deal))
            case .used:
                step = .unavailable(DealOpenResult(status: .used, deal: deal))
            case .expired, .ended:
                step = .unavailable(DealOpenResult(status: .ended, deal: deal))
            }
            await load(using: backend)
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }

    func backToList() { step = .list }

    private func open(_ deal: Deal, near: Bool?, band: DistanceBand, using backend: any GlimpseBackend) async {
        do {
            let result = try await backend.openDeal(deal.id, near: near, band: band)
            if result.status == .available, let pass = result.pass {
                step = .pass(result.deal, pass)
            } else {
                step = .unavailable(result)
            }
        } catch {
            errorMessage = GlimpseError.describe(error)
            step = .list
        }
    }

    private func metersTo(_ deal: Deal) -> Double? {
        guard let here else { return nil }
        return LocationService.meters(from: here, to: .init(latitude: deal.latitude, longitude: deal.longitude))
    }
}
