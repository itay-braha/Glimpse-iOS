import Foundation

/// The answer to "open my pass": the pass, or why not (all given out, used, ended).
struct DealOpenResult: Codable, Hashable, Sendable {
    let status: DealState
    let deal: Deal
    var pass: DealPass?
}
