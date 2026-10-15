import SwiftUI

/// Reporting is private: the other person is never told, and reporting also
/// blocks them. Reports feed the invisible behavioral score.
struct ReportSheet: View {
    let name: String
    let onSubmit: @MainActor (ReportReason, String?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason?
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ReportReason.allCases) { option in
                        Button {
                            reason = option
                        } label: {
                            HStack {
                                Text(option.label).foregroundStyle(Palette.textPrimary)
                                Spacer()
                                if reason == option {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.mint)
                                }
                            }
                        }
                        .accessibilityAddTraits(reason == option ? .isSelected : [])
                    }
                } header: {
                    Text("What happened?")
                } footer: {
                    Text("\(name) won't know you reported them. We'll also block them for you.")
                }

                Section("Anything else? (optional)") {
                    TextField("Add details", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    Section { ErrorText(errorMessage) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.midnight)
            .navigationTitle("Report \(name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task { await submit() }
                    }
                    .disabled(reason == nil || isSubmitting)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func submit() async {
        guard let reason else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
            try await onSubmit(reason, trimmed.isEmpty ? nil : trimmed)
            dismiss()
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }
}
