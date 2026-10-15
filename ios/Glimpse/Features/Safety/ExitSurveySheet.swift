import SwiftUI

/// "Why did this connection end?" Private: it only feeds the behavioral score,
/// is never shown to anyone, and can be skipped.
struct ExitSurveySheet: View {
    let name: String
    let onAnswer: (ExitReason?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ExitReason.allCases) { reason in
                        Button(reason.label) { finish(reason) }
                            .foregroundStyle(Palette.textPrimary)
                    }
                } header: {
                    Text("Why did this connection end?")
                } footer: {
                    Text("Only Glimpse sees this. \(name) is never told, and it helps keep ghosters and catfish out.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.midnight)
            .navigationTitle("Quick question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { finish(nil) }
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    private func finish(_ reason: ExitReason?) {
        onAnswer(reason)
        dismiss()
    }
}
