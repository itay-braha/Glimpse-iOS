import SwiftUI

/// Reporting is private: the other person is never told, and reporting also
/// blocks them for good. After sending, the reporter sees that the report was
/// received and is already being handled. `onDone` runs once they close that.
struct ReportSheet: View {
    let name: String
    let onSubmit: @MainActor (ReportReason, String?) async throws -> Void
    var onDone: @MainActor () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason?
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var submitted: ReportReason?

    var body: some View {
        NavigationStack {
            if let submitted {
                ReportReceivedView(name: name, reason: submitted) {
                    dismiss()
                    onDone()
                }
                .navigationBarBackButtonHidden()
            } else {
                form
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(submitted != nil)
    }

    private var form: some View {
        List {
            Section {
                EmptyView()
            } header: {
                Text("What happened?")
            } footer: {
                Text("\(name) won't know you reported them, and you won't see each other on Glimpse again.")
            }

            ForEach(ReportReason.menu, id: \.0) { group in
                Section(group.0.title) {
                    ForEach(group.1) { option in
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
                }
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

    private func submit() async {
        guard let reason else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
            try await onSubmit(reason, trimmed.isEmpty ? nil : trimmed)
            withAnimation(.smooth) { submitted = reason }
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }
}

/// "We've got you": the report is in, they're blocked for good, and the safety
/// team is already on it.
private struct ReportReceivedView: View {
    let name: String
    let reason: ReportReason
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(Palette.mint)
                .symbolEffect(.bounce, options: .nonRepeating)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("We've got your report")
                    .font(.glimpseTitle2)
                    .foregroundStyle(Palette.textPrimary)
                Text(reason.isUrgent
                     ? String(localized: "Thank you for telling us. We accepted your report and our safety team is dealing with it right now, for your safety and everyone's.")
                     : String(localized: "Thank you for telling us. We accepted your report and our safety team will look into it, for your safety and everyone's."))
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 14) {
                Label("You and \(name) won't see or reach each other on Glimpse again.", systemImage: "eye.slash.fill")
                Label("\(name) isn't told that you reported them.", systemImage: "lock.fill")
                Label("Your conversation, including anything deleted, is kept for the review.", systemImage: "doc.text.magnifyingglass")
            }
            .font(.subheadline)
            .foregroundStyle(Palette.textPrimary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: .rect(cornerRadius: 20))

            Spacer()

            Button("Done", action: onDone)
                .buttonStyle(.glimpse)
                .accessibilityIdentifier("report.done")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.midnight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("report.received")
    }
}
