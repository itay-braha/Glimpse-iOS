import MapKit
import Observation

/// Live city suggestions from Apple Maps as someone types ("tel a" → Tel Aviv-Yafo, Israel).
/// Cities only, so everyone in the same place ends up with the same spelling.
@MainActor
@Observable
final class CitySearch: NSObject {
    struct Suggestion: Identifiable, Hashable, Sendable {
        let title: String
        let subtitle: String

        var id: String { title + "|" + subtitle }
    }

    private(set) var suggestions: [Suggestion] = []
    private(set) var isSearching = false

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        completer.addressFilter = MKAddressFilter(including: .locality)
    }

    func update(_ text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            completer.cancel()
            suggestions = []
            isSearching = false
            return
        }
        isSearching = true
        completer.queryFragment = query
    }

    func clear() {
        completer.cancel()
        suggestions = []
        isSearching = false
    }

    fileprivate func receiveResults() {
        var seen = Set<String>()
        let items = completer.results
            .map { Suggestion(title: $0.title, subtitle: $0.subtitle) }
            .filter { seen.insert($0.id).inserted }
        suggestions = Array(items.prefix(6))
        isSearching = false
    }

    fileprivate func receiveFailure() {
        suggestions = []
        isSearching = false
    }
}

// MapKit calls back on the main thread.
extension CitySearch: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        MainActor.assumeIsolated { self.receiveResults() }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        MainActor.assumeIsolated { self.receiveFailure() }
    }
}
