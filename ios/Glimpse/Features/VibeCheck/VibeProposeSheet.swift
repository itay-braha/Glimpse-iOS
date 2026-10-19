import SwiftUI

/// Pick a time for the Vibe Check, "right now" included. It's a suggestion either
/// way: the call only starts once the other person accepts.
struct VibeProposeSheet: View {
    let name: String
    /// Whether I unlocked the Vibe Check (changes only the explanation below).
    let isKeyHolder: Bool
    let onPick: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var custom = Date.now.addingTimeInterval(3_600)

    private var earliest: Date { .now }

    private var suggestions: [(String, Date)] {
        let calendar = Calendar.current
        var result: [(String, Date)] = []
        result.append(("Right now", .now))
        result.append(("In 30 minutes", Date.now.addingTimeInterval(30 * 60)))
        if let tonight = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: .now), tonight > earliest {
            result.append(("Tonight at 8:00 PM", tonight))
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now),
           let evening = calendar.date(bySettingHour: 19, minute: 30, second: 0, of: tomorrow) {
            result.append(("Tomorrow at 7:30 PM", evening))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(suggestions, id: \.0) { suggestion in
                        Button(suggestion.0) { pick(suggestion.1) }
                    }
                } footer: {
                    Text(isKeyHolder
                         ? String(localized: "\(name) gets a notification and joins a short lobby with you before the call starts.")
                         : String(localized: "\(name) accepts first, even for right now. Nobody gets an unexpected ring."))
                }
                Section("Another time") {
                    DatePicker("Time", selection: $custom, in: earliest...Date.now.addingTimeInterval(7 * 86_400))
                    Button("Suggest this time") { pick(custom) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.midnight)
            .navigationTitle("3-Minute Vibe Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func pick(_ date: Date) {
        onPick(date)
        dismiss()
    }
}
