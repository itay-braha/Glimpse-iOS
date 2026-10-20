import Foundation
@testable import Glimpse
import Testing

/// Coffee deals: a live pass instead of a QR, presence checked on the phone.
struct DealTests {
    @Test func distanceBandsNeverCarryTheExactPosition() {
        #expect(DistanceBand(meters: 40) == .under100)
        #expect(DistanceBand(meters: 150) == .under300)
        #expect(DistanceBand(meters: 650) == .under1km)
        #expect(DistanceBand(meters: 4_000) == .farther)
        #expect(DistanceBand(meters: nil) == .unknown)
        #expect(DistanceBand.nearMeters == 200)
    }

    @Test func decodesADealFromTheServer() throws {
        let json = """
        {"id":"00000000-0000-4000-8000-000000000001","spot_id":"00000000-0000-4000-8000-000000000002",
         "place":"Corner Café","category":"cafe","latitude":32.08,"longitude":34.78,"title":"10% off two coffees",
         "state":"available","remaining":6,"distance_km":0.4}
        """
        let deal = try JSONDecoder.glimpse().decode(Deal.self, from: Data(json.utf8))
        #expect(deal.state == .available)
        #expect(deal.remaining == 6)
        #expect(deal.distanceLabel != nil)
    }

    @Test func passThenRedeemThenOncePerWeek() async throws {
        let backend = DemoBackend(seeded: true)
        let deal = try #require(try await backend.dealsNear().first { $0.state == .available && $0.remaining == nil })
        let opened = try await backend.openDeal(deal.id, near: true, band: .under100)
        let pass = try #require(opened.pass)
        #expect(try await backend.redeemDeal(passID: pass.id).status == .redeemed)
        let again = try await backend.openDeal(deal.id, near: true, band: .under100)
        #expect(again.status == .used, "once a week per member at the same place")
    }

    @Test func aCapIsKindlyFinal() async throws {
        let backend = DemoBackend(seeded: true)
        let deals = try await backend.dealsNear()
        #expect(deals.contains { $0.state == .soldOut })
        #expect(deals.contains { $0.remaining == 6 }, "nearly gone shows what's left")
        let soldOut = try #require(deals.first { $0.state == .soldOut })
        let result = try await backend.openDeal(soldOut.id, near: true, band: .under100)
        #expect(result.status == .soldOut)
        #expect(result.pass == nil)
    }
}
